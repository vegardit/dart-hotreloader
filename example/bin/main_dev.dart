/*
 * SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com) and contributors
 * SPDX-FileContributor: Sebastian Thomschke, Vegard IT GmbH
 * SPDX-License-Identifier: Apache-2.0
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
      (msg.level < logging.Level.SEVERE ? io.stdout : io.stderr).write(
          '${msg.time} ${msg.level.name} [${Isolate.current.debugName}] ${msg.loggerName}: ${msg.message}\n'));

  HotReloader.logLevel = logging.Level.CONFIG;

  final reloader = await HotReloader.create();

  await app.main(args);

  await reloader.stop();
  io.exit(0);
}
