/**
 * Copyright 2020 by Vegard IT GmbH (https://vegardit.com) and contributors.
 * SPDX-License-Identifier: Apache-2.0
 *
 * @author Sebastian Thomschke, Vegard IT GmbH
 */
import 'dart:async';
import 'dart:io' as io;
import 'dart:isolate';

import 'package:logging/logging.dart' as logging;
import 'package:hotreloader/hotreloader.dart';

import 'reloadable.dart' as reloadable;

final _LOG = new logging.Logger('hotreloader.test');

Future<void> _writeReloadableDartFile(
    [String content = 'String testfunc() => \'foo\';']) async {
  // waiting for two seconds so that the modification timestamp will be different on
  // filesystems with seconds-only precision
  await Future<void>.delayed(const Duration(seconds: 2));
  final dartFile = new io.File('test/reloadable.dart');
  _LOG.info('Writing to [${dartFile.path}]: $content');
  dartFile.writeAsStringSync(content, flush: true);
}

/* cannot use "pub run test" with hot reload as it results in:
 * kernel-service: Error: Unhandled exception:
 * Bad state: No element
 * #0      Iterable.first (dart:core/iterable.dart:520:7)
 * #1      MappedIterable.first (dart:_internal/iterable.dart:374:31)
 * #2      lookupOrBuildNewIncrementalCompiler (file:///C:/b/s/w/ir/cache/builder/sdk/pkg/vm/bin/kernel_service.dart:400:45)
 * #3      _processLoadRequest (file:///C:/b/s/w/ir/cache/builder/sdk/pkg/vm/bin/kernel_service.dart:679:22)
 * #4      _RawReceivePortImpl._handleMessage (dart:isolate-patch/isolate_patch.dart:174:12)
 *
 * Unhandled exception:
 * Bad state: No element
 * #0      Iterable.first (dart:core/iterable.dart:520:7)
 * #1      MappedIterable.first (dart:_internal/iterable.dart:374:31)
 * #2      lookupOrBuildNewIncrementalCompiler (file:///C:/b/s/w/ir/cache/builder/sdk/pkg/vm/bin/kernel_service.dart:400:45)
 * #3      _processLoadRequest (file:///C:/b/s/w/ir/cache/builder/sdk/pkg/vm/bin/kernel_service.dart:679:22)
 * #4      _RawReceivePortImpl._handleMessage (dart:isolate-patch/isolate_patch.dart:174:12)
 */
Future<void> main() async {
  logging.hierarchicalLoggingEnabled = true;
  logging.Logger.root.onRecord.listen((record) => print(// ignore: avoid_print
      '${record.time} ${record.level.name} [${Isolate.current.debugName}] ${record.loggerName}: ${record.message}'));

  HotReloader.logLevel = logging.Level.FINEST;

  await test_programmatic_reload();
  await test_automatic_reload();

  _LOG.info('*** ALL TESTS COMPLETED.***');
  io.exit(0);
}

Future<void> test_programmatic_reload() async {
  _LOG.info('TEST: test_programmatic_reload...');

  var callbacksTriggered = 0;
  final hotreloader = await HotReloader.create(
    automaticReload: false,
    debounceInterval: const Duration(seconds: 0), //
    onBeforeReload: (ctx) {
      callbacksTriggered++;
      return true;
    },
    onAfterReload: (ctx) {
      callbacksTriggered++;
    },
  );

  try {
    assert(reloadable.testfunc() == 'foo');
    await _writeReloadableDartFile('String testfunc() => \'bar\';');

    // perform programmatic code reload
    assert(await hotreloader.reloadCode() == HotReloadResult.Succeeded);
    assert(reloadable.testfunc() == 'bar');
    assert(callbacksTriggered == 2);
  } finally {
    // restore initial state
    await _writeReloadableDartFile();
    assert(await hotreloader.reloadCode() == HotReloadResult.Succeeded);
    assert(reloadable.testfunc() == 'foo');

    await hotreloader.stop();
  }
}

Future<void> test_automatic_reload() async {
  _LOG.info('TEST: test_automatic_reload...');

  final reloaded = new Completer<void>();
  final hotreloader = await HotReloader.create(
    debounceInterval: const Duration(seconds: 0), //
    onAfterReload: (ctx) {
      if (!reloaded.isCompleted) reloaded.complete();
    },
  );

  try {
    assert(reloadable.testfunc() == 'foo');
    await _writeReloadableDartFile('String testfunc() => \'bar\';');

    // wait for automatic code reload
    await reloaded.future;
    assert(reloadable.testfunc() == 'bar');
  } finally {
    // restore initial state
    await _writeReloadableDartFile();
    assert(await hotreloader.reloadCode() == HotReloadResult.Succeeded);
    assert(reloadable.testfunc() == 'foo');

    await hotreloader.stop();
  }
}
