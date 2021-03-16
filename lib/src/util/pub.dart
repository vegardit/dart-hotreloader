/**
 * Copyright 2020-2021 by Vegard IT GmbH (https://vegardit.com) and contributors.
 * SPDX-License-Identifier: Apache-2.0
 *
 * @author Sebastian Thomschke, Vegard IT GmbH
 */
import 'dart:io' as io;
import 'dart:isolate' as isolate;
import 'package:path/path.dart' as p;

late final io.File _packagesFile;
bool _packagesFileInitialized = false;
Future<io.File> get packagesFile async {
  if (!_packagesFileInitialized) {
    final path = (await isolate.Isolate.packageConfig)?.toFilePath() ?? '.packages';
    _packagesFile = new io.File(path).absolute;
    _packagesFileInitialized = true;
  }
  return _packagesFile;
}

late final io.Directory _pubCacheDir;
bool _pubCacheDirInitialized = false;
io.Directory get pubCacheDir {
  if (!_pubCacheDirInitialized) {
    final env = io.Platform.environment;
    final path = env['PUB_CACHE'] ??
        (io.Platform.isWindows //
            ? '${env['APPDATA']}\\Pub\\Cache' //
            : '${env['HOME']}/.pub-cache' //
        );
    _pubCacheDir = new io.Directory(p.normalize(path)).absolute;
    _pubCacheDirInitialized = true;
  }
  return _pubCacheDir;
}
