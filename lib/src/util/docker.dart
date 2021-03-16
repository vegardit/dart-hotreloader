/**
 * Copyright 2020-2021 by Vegard IT GmbH (https://vegardit.com) and contributors.
 * SPDX-License-Identifier: Apache-2.0
 *
 * @author Sebastian Thomschke, Vegard IT GmbH
 */
import 'dart:convert' as convert;
import 'dart:io';

bool? _isRunningInDockerContainer;

/**
 * @return true if the program is running within a docker container
 */
Future<bool> isRunningInDockerContainer() async {
  if (_isRunningInDockerContainer == null) {
    final cgroup = new File('/proc/1/cgroup');
    if (!cgroup.existsSync()) {
      _isRunningInDockerContainer = false;
    } else {
      _isRunningInDockerContainer = '' !=
          await cgroup
              .openRead()
              .transform(convert.utf8.decoder)
              .transform(const convert.LineSplitter())
              .firstWhere((l) => l.contains('/docker'), orElse: () => '');
    }
  }
  return _isRunningInDockerContainer ?? false;
}
