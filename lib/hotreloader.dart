/*
 * SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com) and contributors
 * SPDX-FileContributor: Sebastian Thomschke, Vegard IT GmbH
 * SPDX-License-Identifier: Apache-2.0
 */
import 'dart:async';
import 'dart:convert' as convert;
import 'dart:io' as io;
import 'dart:isolate' as isolates;

import 'package:collection/collection.dart' show IterableExtension;
import 'package:hotreloader/src/util/docker.dart' as docker;
import 'package:hotreloader/src/util/files.dart' show UriExtensions;
import 'package:hotreloader/src/util/pub.dart' as pub;
import 'package:hotreloader/src/util/strings.dart' as strings;
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

/// Hot code swap/reload service that uses https://pub.dev/packages/watcher to
/// monitor the file system for changes in *.dart files
class HotReloader {
  static logging.Level get logLevel {
    return log.level;
  }

  static set logLevel(final logging.Level level) {
    log.level = level;
  }

  /// Creates a new HotReloader instance.
  ///
  /// if [automaticReload] is `false`, reload must be triggered manually via
  /// [HotReloader.reloadCode].
  /// File changes within [debounceInterval] time frame only trigger a single
  /// hot reload.
  ///
  /// [watchDependencies] indicates that changes to library dependencies should
  /// also trigger hot reload.
  ///
  /// [excludedPaths] may contain relative paths that should be excluded from
  /// the watch list.
  /// CAUTION: if the path is inside some of the watched directories, it won't
  /// be excluded.
  /// Usually `bin`, `lib` and `test` are watched. When
  /// [watchDependencies] is `true`, all dependency directories also will be
  /// watched, which include the project root `./` since
  /// `.dart_tool/package_config.json` contains the package of the project
  /// itself. If you don't need watching the entire project's directory, you can
  /// put the path `./` to the [excludedPaths]. Also you can exclude some path
  /// dependencies from your workspace putting `../<my-sub-package>` to the
  /// [excludedPaths].
  static Future<HotReloader> create({
    final bool automaticReload = true,
    final Duration debounceInterval = const Duration(seconds: 1), //
    final bool watchDependencies = true,
    final Set<String>? excludedPaths,
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
      excludedPaths,
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

  final bool Function(BeforeReloadContext ctx)? _onBeforeReload;
  final void Function(AfterReloadContext ctx)? _onAfterReload;

  final Duration _debounceInterval;
  final bool _watchDependencies;
  final Set<String>? _excludedPaths;
  final _watchedStreams = <StreamSubscription<List<WatchEvent>>>{};
  final vms.VmService _vmService;

  /**
   * private constructor
   */
  HotReloader._(
    this._watchDependencies,
    this._excludedPaths,
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
      await stop();
    }

    var watchList = ['bin', 'lib', 'test'];

    if (_watchDependencies) {
      // add .packages file to watch list
      watchList.add((await pub.packagesFile).path);
      // add source folders of all dependencies to watch list
      final pkgConfigURL = await isolates.Isolate.packageConfig;
      if (pkgConfigURL != null) {
        log.config('pkgConfigURL: $pkgConfigURL');
        if (pkgConfigURL.path.endsWith('.json')) {
          convert.json
              .decode(await new io.File(pkgConfigURL.toFilePath()).readAsString())['packages']
              .map((dynamic v) => v['rootUri'].toString())

              // '../' means relative to <project>/.dart_tool
              // since we are already at <project> level we change '../' to './'
              .map((dynamic rootUri) => rootUri.toString().startsWith('../') ? rootUri.substring(1) : rootUri)
              .map((dynamic rootUri) => Uri.parse(rootUri.toString()).toFilePath())
              .forEach(watchList.add);
        } else {
          await pkgConfigURL
              .readLineByLine()
              .where((l) => !l.startsWith('#') && l.contains(':'))
              .map((l) => Uri.parse(strings.substringAfter(l, ':')).toFilePath())
              .forEach(watchList.add);
        }
      }
    }

    final excludedPaths = _excludedPaths;
    if (excludedPaths != null) {
      watchList = watchList.where((e) => !excludedPaths.contains(e)).toList();
    }

    watchList = watchList.map(p.absolute).map(p.normalize).toSet().toList();
    watchList.sort();

    final pubCacheDir = pub.pubCacheDir;
    log.fine('pubCacheDir: [${pubCacheDir.path}]');

    final isDockerized = await docker.isRunningInDockerContainer;
    log.fine('isDockerized: [$isDockerized]');

    final watchers = <Watcher>[];
    for (final path in watchList) {
      if (path == pubCacheDir.path || p.isWithin(pubCacheDir.path, path)) {
        log.fine('Skipped watching cached package at [$path]');
        continue;
      }
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

    final packagesFile = await pub.packagesFile;
    final isPackagesFileChanged = null !=
        changes?.firstWhereOrNull((c) =>
                c.path.endsWith('.packages') && //
                new io.File(c.path).absolute.path == packagesFile.path //
            );

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
            log.fine('Hot-reloading code of isolate [${isolateRef.name}] '
              'has been skipped because of listener veto.'
            );
            continue;
          }
        } else {
          final passedChanges = changes
            .map((change) => BeforeReloadContext(change, isolateRef))
            .map(onBeforeReload)
            .where((passed) => passed)
            .length;
          if (passedChanges <= 0) {
            log.fine('Hot-reloading code of isolate [${isolateRef.name}] '
              'has been skipped: no significant changes.'
            );
            continue;
          }
        }
      }

      try {
        final reloadReport = await _vmService.reloadSources(isolateRef.id!,
            force: force, //
            packagesUri: isPackagesFileChanged ? packagesFile.uri.toString() : null //
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

    if (isPackagesFileChanged) {
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

  Future<void> _onFilesModified(final List<WatchEvent> changes) async {
    // ignore non-dart file changes
    final packagesFile = await pub.packagesFile;
    changes.retainWhere((ev) => ev.path.endsWith('.dart') || ev.path == packagesFile.path);
    if (changes.isEmpty) return;

    for (final event in changes) {
      log.info('Change detected: type=[${event.type}] path=[${event.path}]');
    }
    log.finest(changes);
    await _reloadCode(changes, false);
  }

  bool get isWatching => _watchedStreams.isNotEmpty;

  /**
   * Triggers reload of code from all source files.
   *
   * @param force: indicates that code from all source files should be reloaded regardless of their modification time.
   */
  Future<HotReloadResult> reloadCode({final bool force = false}) async {
    return _reloadCode(null, force);
  }

  /**
   * Stops watching for changes on the file system
   */
  Future<void> stop() async {
    if (_watchedStreams.isNotEmpty) {
      log.info('Stopping to watch paths...');
      await Future.wait<dynamic>(_watchedStreams.map((s) => s.cancel()));
      _watchedStreams.clear();
    } else {
      log.fine('Was not watching any paths.');
    }

    // to prevent "Unhandled exception: reloadSources: (-32000) Service connection disposed"
    await Future<void>.delayed(const Duration(seconds: 2));

    await _vmService.dispose();
  }
}
