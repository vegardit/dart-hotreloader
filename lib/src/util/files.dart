/*
 * SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com) and contributors
 * SPDX-FileContributor: Sebastian Thomschke, Vegard IT GmbH
 * SPDX-License-Identifier: Apache-2.0
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
