/*
 * SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com) and contributors
 * SPDX-FileContributor: Sebastian Thomschke, Vegard IT GmbH
 * SPDX-License-Identifier: Apache-2.0
 */
import 'dart:convert' as convert;
import 'dart:io';

final Future<bool> isRunningInDockerContainer = _isRunningInDockerContainer();

/**
 * @return true if the program is running within a docker container
 */
Future<bool> _isRunningInDockerContainer() async {
  final cgroup = new File('/proc/1/cgroup');
  if (!cgroup.existsSync()) {
    return false;
  }
  return '' !=
      await cgroup
          .openRead()
          .transform(convert.utf8.decoder)
          .transform(const convert.LineSplitter())
          .firstWhere((l) => l.contains('/docker'), orElse: () => '');
}
