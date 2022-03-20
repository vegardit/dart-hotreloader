/**
 * Copyright 2020-2022 by Vegard IT GmbH (https://vegardit.com) and contributors.
 * SPDX-License-Identifier: Apache-2.0
 *
 * @author Sebastian Thomschke, Vegard IT GmbH
 */

String substringAfter(final String searchIn, final String searchFor) {
  if (searchIn.isEmpty) {
    return searchIn;
  }

  final pos = searchIn.indexOf(searchFor);
  return pos < 0 ? '' : searchIn.substring(pos + searchFor.length);
}
