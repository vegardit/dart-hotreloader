/*
 * SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com) and contributors
 * SPDX-FileContributor: Sebastian Thomschke, Vegard IT GmbH
 * SPDX-License-Identifier: Apache-2.0
 */

String substringAfter(final String searchIn, final String searchFor) {
  if (searchIn.isEmpty) {
    return searchIn;
  }

  final pos = searchIn.indexOf(searchFor);
  return pos < 0 ? '' : searchIn.substring(pos + searchFor.length);
}
