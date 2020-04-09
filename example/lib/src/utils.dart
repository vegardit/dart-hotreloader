/**
 * Copyright 2020 by Vegard IT GmbH (https://vegardit.com) and contributors.
 * SPDX-License-Identifier: Apache-2.0
 *
 * @author Sebastian Thomschke, Vegard IT GmbH
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
