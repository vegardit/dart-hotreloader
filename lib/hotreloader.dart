/*
 * SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com) and contributors
 * SPDX-FileContributor: Sebastian Thomschke, Vegard IT GmbH
 * SPDX-License-Identifier: Apache-2.0
 */
import 'dart:async';
import 'dart:io' as io;

import 'package:hotreloader/src/package.dart';
import 'package:hotreloader/src/util/docker.dart' as docker;
import 'package:hotreloader/src/util/iterable.dart';
import 'package:hotreloader/src/util/vm.dart' as vm_utils;
import 'package:logging/logging.dart' as logging;
import 'package:path/path.dart' as p;
import 'package:stream_transform/stream_transform.dart' show RateLimit; // debounceBuffer
import 'package:vm_service/vm_service.dart' as vms;
import 'package:watcher/watcher.dart';

final log = new logging.Logger('hotreloader');

enum HotReloadResult {
  /**
   * Hot-reloading was not performed because of a veto by the onBeforeReload listener.
   */
  Skipped,

  /**
   * Hot-reloading of all isolate failed.
   */
  Failed,

  /**
   * Hot-reloading of some isolates failed.
   */
  PartiallySucceeded,

  /**
   * Hot-reloading of all isolates succeeded.
   */
  Succeeded
}

class BeforeReloadContext {
  /**
   * Is `null` on programmatic invocation of `HotReloader#reloadCode()`,
   * otherwise `non-null`
   */
  final WatchEvent? event;

  final vms.IsolateRef isolate;

  BeforeReloadContext(this.event, this.isolate);
}

class AfterReloadContext {
  final Iterable<WatchEvent>? events;
  final Map<vms.IsolateRef, vms.ReloadReport> reloadReports;
  final HotReloadResult result;

  AfterReloadContext(this.events, this.reloadReports, this.result);
}

/**
 * Hot code swap/reload service that uses https://pub.dev/packages/watcher to
 * monitor the file system for changes in *.dart files
 */
class HotReloader {
  static logging.Level get logLevel {
    return log.level;
  }

  static set logLevel(final logging.Level level) {
    log.level = level;
  }

  /**
   * Creates a new HotReloader instance that monitors and reloads Dart code changes.
   *
   * By default, watches `bin`, `lib`, and `test` directories for changes
   * and automatically triggers hot reload when Dart files are modified.
   *
   * Set [automaticReload] to `false` to require manual reload via [reloadCode].
   *
   * The [debounceInterval] specifies the minimum time between reloads; changes within this window are batched together.
   *
   * When [watchDependencies] is `true`, changes to package dependencies also trigger reload.
   *
   * [packagePathsToWatch] specifies which subdirectories inside the package
   * should be watched, relative to the **package** root. By default it contains
   * `bin`, `lib`, and `test`.
   *
   * [projectPathsToExclude] removes paths from the calculated watch list before
   * watchers are created, relative to the **project** root.
   * **Note:** Only works on top-level paths; cannot exclude subdirectories of
   * watched directories.
   * Common uses:
   * - Exclude default directories like `test` if not needed.
   * - Exclude specific local dependencies from triggering reloads.
   *
   * If the project is a pub workspace, the `test` folder of the package will be
   * located in the `packages/<package>` folder. That means it should be
   * specified like `packages/<package>/test` in [projectPathsToExclude], where
   * `<package>` is the name of the package where the `HotReloader` is created.
   * If the project consists of a single package, the `test` directory lies in
   * the project's root folder and should be specified like `test` in
   * [projectPathsToExclude].
   *
   * The [onBeforeReload] callback can veto reloads by returning `false`.
   *
   * The [onAfterReload] callback receives reload results for custom handling.
   */
  static Future<HotReloader> create({
    final bool automaticReload = true,
    final Duration debounceInterval = const Duration(seconds: 1),
    final bool watchDependencies = true,
    final Set<String> packagePathsToWatch = const { 'bin', 'lib', 'test' },
    final Set<String>? projectPathsToExclude,
    final bool Function(BeforeReloadContext ctx)? onBeforeReload,
    final void Function(AfterReloadContext ctx)? onAfterReload,
  }) async {
    if (!new io.File('pubspec.yaml').existsSync()) {
      throw StateError('''
Error: [pubspec.yaml] file not found in current directory.
For hot code reloading to function properly, Dart needs to be run from the root of your project.''');
    }

    final instance = new HotReloader._(
      watchDependencies,
      packagePathsToWatch,
      projectPathsToExclude,
      debounceInterval,
      await vm_utils.createVmService(),
      onBeforeReload,
      onAfterReload,
    );

    if (automaticReload) {
      await instance._registerWatchers();
    }
    return instance;
  }

  bool _isStopping = false;
  Future<void> _pendingAutomaticReload = Future<void>.value();

  final bool Function(BeforeReloadContext ctx)? _onBeforeReload;
  final void Function(AfterReloadContext ctx)? _onAfterReload;

  final Duration _debounceInterval;
  final bool _watchDependencies;
  final Set<String> _packagePathsToWatch;
  final Set<String>? _projectPathsToExclude;
  final _watchedStreams = <StreamSubscription<List<WatchEvent>>>{};
  final vms.VmService _vmService;

  /**
   * private constructor
   */
  HotReloader._(
    this._watchDependencies,
    this._packagePathsToWatch,
    this._projectPathsToExclude,
    this._debounceInterval,
    this._vmService,
    this._onBeforeReload,
    this._onAfterReload,
  );

  /**
   * registers all required file/directory watchers
   */
  Future<void> _registerWatchers() async {
    if (_watchedStreams.isNotEmpty) {
      await _stopWatching();
    }

    await Package.init();
    final packageUri = Package.packageUri;
    if (packageUri == null) {
      log.warning('Failed to watch: unable to define the package uri.');
      return;
    }
    final projectUri = Package.projectUri ?? packageUri;
    final projectPathsToExclude = (_projectPathsToExclude ?? const {})
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map(p.normalize)
        .map(Uri.directory)
        .map(projectUri.resolveUri)
        .map((e) => e.toFilePath())
        .toSet();
    final watchList = _packagePathsToWatch
        .map(Uri.directory)
        .map(packageUri.resolveUri)
        .map((e) => e.toFilePath())
        .whereIf(projectPathsToExclude.isNotEmpty,
          (e) => !projectPathsToExclude.contains(e),
        )
        .toList();

    final configUri = Package.configUri;
    if (configUri != null) {
      watchList.add(configUri.toFilePath());
    }
    final graphUri = Package.graphUri;
    if (graphUri != null) {
      watchList.add(graphUri.toFilePath());
    }

    if (_watchDependencies) {
      final dependencies = Package.dependencies;
      if (dependencies == null) {
        log.warning('Failed to watch package dependencies: not defined.');
      } else {
        dependencies
            .where((e) => !e.isPubCached)
            .map((e) => e.uri.toFilePath())
            .whereIf(projectPathsToExclude.isNotEmpty,
              (e) => !projectPathsToExclude.contains(e),
            )
            .forEach(watchList.add);
      }
    }

    watchList.sort();

    final isDockerized = await docker.isRunningInDockerContainer;
    log.fine('isDockerized: [$isDockerized]');

    final watchers = <Watcher>[];
    for (final path in watchList) {
      if (watchers.where((w) => path == w.path || p.isWithin(w.path, path)).isNotEmpty) {
        log.fine('Skipped watching [$path] since parent path is already being watched');
        continue;
      }

      final fileType = io.FileSystemEntity.typeSync(path);
      if (fileType == io.FileSystemEntityType.file) {
        watchers.add(isDockerized //
                ? new PollingFileWatcher(path, pollingDelay: _debounceInterval) //
                : new FileWatcher(path) //
            );
      } else if (fileType == io.FileSystemEntityType.notFound) {
        watchers.add(new PollingDirectoryWatcher(path, pollingDelay: _debounceInterval));
      } else {
        watchers.add(isDockerized
            ? new PollingDirectoryWatcher(path, pollingDelay: _debounceInterval)
            : new DirectoryWatcher(path));
      }
    }

    for (final watcher in watchers) {
      log.config('Watching [${watcher.path}] with [${watcher.runtimeType}]...');
      final watchedStream = watcher.events //
          .debounceBuffer(_debounceInterval) //
          .listen(_onFilesModified);
      await watcher.ready;
      _watchedStreams.add(watchedStream);
    }
  }

  /**
   * reloads the code of all isolates
   */
  Future<HotReloadResult> _reloadCode(
    final List<WatchEvent>? changes,
    final bool force,
  ) async {
    log.info('Hot-reloading code...');

    final configPaths = {Package.configUri?.toFilePath(), Package.graphUri?.toFilePath()};
    final isConfigFileChanged =
        changes != null && changes.any((c) => configPaths.contains(io.File(c.path).absolute.path));

    final reloadReports = <vms.IsolateRef, vms.ReloadReport>{};
    final failedReloadReports = <vms.IsolateRef, vms.ReloadReport>{};
    for (final isolateRef in (await _vmService.getVM()).isolates ?? <vms.IsolateRef>[]) {
      if (isolateRef.id == null) {
        log.fine('Cannot hot-reload code of isolate [${isolateRef.name}] since its ID is null.');
        continue;
      }
      log.fine('Hot-reloading code of isolate [${isolateRef.name}]...');

      final onBeforeReload = _onBeforeReload;
      if (onBeforeReload != null) {
        if (changes == null) {
          final passed = onBeforeReload(BeforeReloadContext(null, isolateRef));
          if (!passed) {
            log.fine('Hot-reloading code of isolate [${isolateRef.name}] has been skipped because of listener veto.');
            continue;
          }
        } else {
          final passedChanges = changes
              .map((change) => BeforeReloadContext(change, isolateRef))
              .map(onBeforeReload)
              .where((passed) => passed)
              .length;
          if (passedChanges <= 0) {
            log.fine('Hot-reloading code of isolate [${isolateRef.name}] has been skipped: no significant changes.');
            continue;
          }
        }
      }

      try {
        final reloadReport = await _vmService.reloadSources(
          isolateRef.id!,
          force: force,
        );
        if (!(reloadReport.success ?? false)) {
          failedReloadReports[isolateRef] = reloadReport;
        }
        reloadReports[isolateRef] = reloadReport;
        log.finest('reloadReport for [${isolateRef.name}]: $reloadReport');
      } on vms.SentinelException catch (ex) {
        // happens when the isolate has been garbage collected in the meantime
        log.warning('Failed to reload code of isolate [${isolateRef.name}]: $ex');
      }
    }

    if (isConfigFileChanged && !_isStopping) {
      await _registerWatchers();
    }

    if (reloadReports.isEmpty) {
      log.info('Hot-reloading code skipped because of listener veto.');
      return HotReloadResult.Skipped;
    }

    if (failedReloadReports.isEmpty) {
      log.info('Hot-reloading code succeeded.');
      _onAfterReload?.call(new AfterReloadContext(changes, reloadReports, HotReloadResult.Succeeded));
      return HotReloadResult.Succeeded;
    }

    if (failedReloadReports.length == reloadReports.length) {
      //{type:ReloadReport,success:false,notices:[{type:ReasonForCancelling,message:"lib/src/config.dart:32:1: Error: Expected ';' after this."}]}
      log.severe('Hot-reloading code failed:\n ${failedReloadReports.values.first.json?['notices'][0]['message']}');
      _onAfterReload?.call(new AfterReloadContext(changes, reloadReports, HotReloadResult.Failed));
      return HotReloadResult.Failed;
    }

    final failedIsolates = failedReloadReports.keys.map((i) => '${i.name}@${i.number}').join(',');
    log.severe(
        'Hot-reloading code failed for some isolates [$failedIsolates]:\n ${failedReloadReports.values.first.json?['notices'][0]['message']}');
    _onAfterReload?.call(new AfterReloadContext(changes, reloadReports, HotReloadResult.PartiallySucceeded));
    return HotReloadResult.PartiallySucceeded;
  }

  Future<void> _stopWatching() async {
    if (_watchedStreams.isNotEmpty) {
      log.info('Stopping to watch paths...');
      await Future.wait<dynamic>(_watchedStreams.map((s) => s.cancel()));
      _watchedStreams.clear();
    } else {
      log.fine('Was not watching any paths.');
    }
  }

  Future<void> _onFilesModified(final List<WatchEvent> changes) {
    if (_isStopping) return Future<void>.value();

    final configPaths = {Package.configUri?.toFilePath(), Package.graphUri?.toFilePath()};
    changes.retainWhere((ev) => ev.path.endsWith('.dart') || configPaths.contains(io.File(ev.path).absolute.path));
    if (changes.isEmpty) return Future<void>.value();

    for (final event in changes) {
      log.info('Change detected: type=[${event.type}] path=[${event.path}]');
    }
    log.finest(changes);

    // Buffered watcher callbacks can still arrive while stop() is tearing down on
    // slower machines. Drain them in order so the VM service stays alive until the
    // last accepted automatic reload has finished.
    final previousAutomaticReload = _pendingAutomaticReload;
    return _pendingAutomaticReload = () async {
      try {
        await previousAutomaticReload;
      } catch (_) {
        // Keep later reloads flowing even if an earlier callback failed.
      }
      if (_isStopping) return;
      await _reloadCode(changes, false);
    }();
  }

  bool get isWatching => _watchedStreams.isNotEmpty;

  /**
   * Triggers reload of code from all source files.
   *
   * @param force: indicates that code from all source files should be reloaded regardless of their modification time.
   */
  Future<HotReloadResult> reloadCode({final bool force = false}) {
    return _reloadCode(null, force);
  }

  /**
   * Stops watching for changes on the file system and dispose the [HotReloader].
   *
   * After that you can't [reloadCode] anymore. Instead, you should create a new
   * [HotReloader].
   */
  Future<void> stop() async {
    _isStopping = true;
    await _stopWatching();
    await _pendingAutomaticReload;
    await _vmService.dispose();
  }
}
