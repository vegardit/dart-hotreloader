/*
 * SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com) and contributors
 * SPDX-FileContributor: Sebastian Thomschke, Vegard IT GmbH
 * SPDX-License-Identifier: Apache-2.0
 */

import 'package:dummylib/dummylib.dart' as dummylib;

int _counter = 0;

String getSystemInfo() {
  return [
    'Date: ${DateTime.now()}',
    'Counter: ${_counter++}',
    'Dummy Lib Version: ${dummylib.getVersion()}',
    'Hello!!'
  ].join(' | ');
}
