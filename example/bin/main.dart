/*
 * SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com) and contributors
 * SPDX-FileContributor: Sebastian Thomschke, Vegard IT GmbH
 * SPDX-License-Identifier: Apache-2.0
 */

import 'dart:async';

import 'package:hotreloader_example/src/utils.dart';

/*
 * entry point method
 */
Future<void> main(List<String> args) async {
  // ignore: literal_only_boolean_expressions
  while (true) {
    await Future.delayed(const Duration(seconds: 1), () {
      // ignore: avoid_print
      print('getSystemInfo(): ${getSystemInfo()}');
    });
  }
}
