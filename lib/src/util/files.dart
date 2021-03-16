/**
 * Copyright 2020-2021 by Vegard IT GmbH (https://vegardit.com) and contributors.
 * SPDX-License-Identifier: Apache-2.0
 *
 * @author Sebastian Thomschke, Vegard IT GmbH
 */

import 'dart:convert' as convert;
import 'dart:io' as io;

extension FileExtensions on io.File {
  Stream<String> readLineByLine() {
    if (!existsSync()) {
      return const Stream<String>.empty();
    }

    return openRead() //
        .transform(convert.utf8.decoder) //
        .transform(const convert.LineSplitter());
  }
}

extension UriExtensions on Uri {
  Stream<String> readLineByLine() {
    return new io.File(toFilePath()) //
        .readLineByLine();
  }
}
