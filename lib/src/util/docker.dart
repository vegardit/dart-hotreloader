/**
 * Copyright 2020-2021 by Vegard IT GmbH (https://vegardit.com) and contributors.
 * SPDX-License-Identifier: Apache-2.0
 *
 * @author Sebastian Thomschke, Vegard IT GmbH
 */
import 'dart:convert' as convert;
import 'dart:io';

late final Future<bool> isRunningInDockerContainer = _isRunningInDockerContainer();

/**
 * @return true if the program is running within a docker container
 */
Future<bool> _isRunningInDockerContainer() async {
  final cgroup = new File('/proc/1/cgroup');
  if (!await cgroup.exists()) {
    return false;
  }
  return '' !=
    await cgroup
        .openRead()
        .transform(convert.utf8.decoder)
        .transform(const convert.LineSplitter())
        .firstWhere((l) => l.contains('/docker'), orElse: () => '');
}
