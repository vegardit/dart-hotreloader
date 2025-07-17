#!/usr/bin/env bash
# SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com) and contributors
# SPDX-FileContributor: Sebastian Thomschke, Vegard IT GmbH
# SPDX-License-Identifier: Apache-2.0

if [ "$1" == "--help" ]; then
   echo "Formats the source code."
   echo
   echo "Usage: $(basename $0)"
   exit 0
fi

set -eux

dart format "$(dirname "$0")/../lib"
dart format "$(dirname "$0")/../test"
