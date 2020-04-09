/**
 * Copyright 2020 by Vegard IT GmbH (https://vegardit.com) and contributors.
 * SPDX-License-Identifier: Apache-2.0
 *
 * @author Sebastian Thomschke, Vegard IT GmbH
 */
import 'dart:io' as io;
import 'dart:isolate';

import 'package:hotreloader/hotreloader.dart';
import 'package:logging/logging.dart' as logging;

import 'main.dart' as app;

/*
 * entry point method with hot reloading enabled, requires dart to be executed with --enable-vm-service
 */
Future<void> main(List<String> args) async {
  logging.hierarchicalLoggingEnabled = true;
  // print log messages to stdout/stderr
  logging.Logger.root.onRecord.listen((msg) =>
      (msg.level < logging.Level.SEVERE ? io.stdout : io.stderr).writeln(
          '${msg.time} ${msg.level.name} [${Isolate.current.debugName}] ${msg.loggerName}: ${msg.message}'));

  HotReloader.logLevel = logging.Level.CONFIG;

  final reloader = await HotReloader.create();

  await app.main(args);

  await reloader.stop();
  io.exit(0);
}
