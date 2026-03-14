/*
 * SPDX-FileCopyrightText: © RightbrainPro (https://rightbrain.pro) and contributors
 * SPDX-FileContributor: Serj Elokhin, RightbrainPro
 * SPDX-License-Identifier: Apache-2.0
 */
typedef Test<E> = bool Function(E element);
typedef Convert<T, E> = T Function(E element);

extension ConditionalWhere<E> on Iterable<E>
{
  Iterable<E> whereIf(final bool condition, final Test<E> test) =>
    condition ? where(test) : this;
}
