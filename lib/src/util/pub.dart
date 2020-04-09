/**
 * Copyright 2020 by Vegard IT GmbH (https://vegardit.com) and contributors.
 * SPDX-License-Identifier: Apache-2.0
 *
 * @author Sebastian Thomschke, Vegard IT GmbH
 */
import 'dart:io' as io;
import 'dart:isolate' as isolate;
import 'package:path/path.dart' as p;

io.File _packagesFile;
Future<io.File> get packagesFile async {
  if (_packagesFile == null) {
    final path =
        (await isolate.Isolate.packageConfig)?.toFilePath() ?? '.packages';
    _packagesFile = new io.File(path).absolute;
  }
  return _packagesFile;
}

io.Directory _pubCacheDir;
io.Directory get pubCacheDir {
  if (_pubCacheDir == null) {
    final env = io.Platform.environment;
    final path = //
        env.containsKey('PUB_CACHE')
            ? env['PUB_CACHE']
            : io.Platform.isWindows
                ? p.join(env['APPDATA'], 'Pub', 'Cache')
                : '${env['HOME']}/.pub-cache';
    _pubCacheDir = new io.Directory(p.normalize(path)).absolute;
  }
  return _pubCacheDir;
}
