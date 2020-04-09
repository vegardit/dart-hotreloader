/**
 * Copyright 2020 by Vegard IT GmbH (https://vegardit.com) and contributors.
 * SPDX-License-Identifier: Apache-2.0
 *
 * @author Sebastian Thomschke, Vegard IT GmbH
 */

extension IterableExtensions<E> on Iterable<E> {
  E firstWhereOrNull(bool Function(E element) test) {
    return firstWhere(test, orElse: () => null);
  }
}
