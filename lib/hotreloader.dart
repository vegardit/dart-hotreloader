/**
 * Copyright 2020 by Vegard IT GmbH (https://vegardit.com) and contributors.
 * SPDX-License-Identifier: Apache-2.0
 *
 * @author Sebastian Thomschke, Vegard IT GmbH
 */
import 'dart:async';

import 'package:logging/logging.dart' as logging;
import 'package:path/path.dart' as p;
import 'package:stream_transform/stream_transform.dart'
    show RateLimit; // debounceBuffer
import 'package:vm_service/vm_service.dart' as vms;
import 'package:watcher/watcher.dart';

import 'src/util/docker.dart' show isRunningInDockerContainer;
import 'src/util/vm.dart' show getVmService;

final _LOG = new logging.Logger('hotreloader');

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
  final WatchEvent event;

  /**
   * Is never `null`
   */
  final vms.IsolateRef isolate;

  BeforeReloadContext(this.event, this.isolate);
}

class AfterReloadContext {
  final Set<WatchEvent> events;
  final Map<vms.IsolateRef, vms.ReloadReport> reloadReports;
  final HotReloadResult result;

  AfterReloadContext(this.events, this.reloadReports, this.result);
}

/**
 * Hot code swap/reload service that uses https://pub.dev/packages/watcher to monitor the file system for changes in *.dart files
 */
class HotReloader {
  static logging.Level get logLevel {
    return _LOG.level;
  }

  static set logLevel(logging.Level level) {
    _LOG.level = level;
  }

  /**
   * Creates a new HotReloader instance
   *
   * @param paths list of source directories to watch for file changes, defaults to the current directory and its sub-directories
   * @param debounceInterval file changes within this time frame only trigger a single code reload
   *
   * @throws ArgumentError if [paths] is null or empty
   */
  static Future<HotReloader> create({
    Iterable<String> paths = const ['lib'],
    Duration debounceInterval = const Duration(seconds: 1), //
    bool Function(BeforeReloadContext ctx) onBeforeReload,
    void Function(AfterReloadContext ctx) onAfterReload,
  }) async {
    if (paths == null || paths.isEmpty) {
      throw new ArgumentError('[paths] cannot be null or empty!');
    }

    final instance =
        new HotReloader._(await getVmService(), onBeforeReload, onAfterReload);
    final isDockerized = await isRunningInDockerContainer();
    final dirWatchers = paths.map(p.absolute).toSet().map((path) =>
        // native watcher implementation does not work in docker esp. with a mapped windows drives
        isDockerized
            ? new PollingDirectoryWatcher(path)
            : new DirectoryWatcher(path));

    for (final watcher in dirWatchers) {
      _LOG.info('Watching [${watcher.path}] using [${watcher.runtimeType}]...');
      final watchedStream = watcher.events
          .debounceBuffer(debounceInterval)
          .listen(instance._onFilesModified);
      await watcher.ready;
      instance._watchedStreams.add(watchedStream);
    }
    return instance;
  }

  final bool Function(BeforeReloadContext ctx) _onBeforeReload;
  final void Function(AfterReloadContext ctx) _onAfterReload;

  final _watchedStreams = <StreamSubscription<List<WatchEvent>>>{};
  final vms.VmService _vmService;

  /**
   * private constructor
   */
  HotReloader._(this._vmService, this._onBeforeReload, this._onAfterReload);

  Future<HotReloadResult> _reloadCode(
      {Set<WatchEvent> changes, bool force = false}) async {
    _LOG.info('Hot-reloading code...');

    final vm = await _vmService.getVM();

    final reloadReports = <vms.IsolateRef, vms.ReloadReport>{};
    final failedReloadReports = <vms.IsolateRef, vms.ReloadReport>{};
    for (final isolate in vm.isolates) {
      _LOG.fine('Hot-reloading code of isolate [${isolate.name}]...');

      var noVeto = true;
      if (_onBeforeReload != null) {
        if (changes?.isEmpty ?? true) {
          noVeto = _onBeforeReload.call(new BeforeReloadContext(null, isolate));
        } else {
          for (final change in changes) {
            if (!_onBeforeReload
                .call(new BeforeReloadContext(change, isolate))) {
              noVeto = false;
            }
          }
        }
      }

      if (noVeto) {
        try {
          final reloadReport =
              await _vmService.reloadSources(isolate.id, force: force);
          if (!reloadReport.success) {
            failedReloadReports[isolate] = reloadReport;
          }
          reloadReports[isolate] = reloadReport;
          _LOG.finest('reloadReport for [${isolate.name}]: $reloadReport');
        } on vms.SentinelException catch (ex) {
          // happens when the isolate has been garbge collected in the meantime
          _LOG.warning(
              'Failed to reload code of isolate [${isolate.name}]: $ex');
        }
      } else {
        _LOG.fine(
            'Skipped hot-reloading code of isolate [${isolate.name}] because of listener veto.');
      }
    }

    if (reloadReports.isEmpty) {
      _LOG.info('Hot-reloading code skipped because of listener veto.');
      return HotReloadResult.Skipped;
    }

    if (failedReloadReports.isEmpty) {
      _LOG.info('Hot-reloading code succeeded.');
      _onAfterReload?.call(new AfterReloadContext(
          changes, reloadReports, HotReloadResult.Succeeded));
      return HotReloadResult.Succeeded;
    }

    if (failedReloadReports.length == reloadReports.length) {
      //{type:ReloadReport,success:false,notices:[{type:ReasonForCancelling,message:"lib/src/config.dart:32:1: Error: Expected ';' after this."}]}
      _LOG.severe(
          'Hot-reloading code failed:\n ${failedReloadReports.values.first.json['notices'][0]['message']}');
      _onAfterReload?.call(new AfterReloadContext(
          changes, reloadReports, HotReloadResult.Failed));
      return HotReloadResult.Failed;
    }

    final failedIsolates =
        failedReloadReports.keys.map((i) => '${i.name}@${i.number}').join(',');
    _LOG.severe(
        'Hot-reloading code failed for some isolates [$failedIsolates]:\n ${failedReloadReports.values.first.json['notices'][0]['message']}');
    _onAfterReload?.call(new AfterReloadContext(
        changes, reloadReports, HotReloadResult.PartiallySucceeded));
    return HotReloadResult.PartiallySucceeded;
  }

  void _onFilesModified(final List<WatchEvent> changes) {
    final distinctChanges = changes.toSet();

    // ignore non-dart file changes
    distinctChanges.retainWhere((ev) => ev.path.endsWith('.dart'));
    if (distinctChanges.isEmpty) return;

    for (final event in distinctChanges) {
      _LOG.info('Change detected: type=[${event.type}] path=[${event.path}]');
    }
    _LOG.finest(distinctChanges);
    _reloadCode(changes: distinctChanges);
  }

  bool get isWatching => _watchedStreams.isNotEmpty;

  /**
   * Triggers reload of code from all source files.
   *
   * @param force: indicates that code from all source files should be reloaded regardless of their modification time.
   */
  Future<HotReloadResult> reloadCode({bool force = false}) async {
    return _reloadCode(changes: null, force: force);
  }

  /**
   * Stops watching for changes on the file system
   */
  Future<void> stop() async {
    if (_watchedStreams.isNotEmpty) {
      _LOG.info('Stopping to watch paths...');
      await Future.wait<dynamic>(_watchedStreams.map((s) => s.cancel()));
      _watchedStreams.clear();
    } else {
      _LOG.info('Was not watching any paths.');
    }
  }
}
