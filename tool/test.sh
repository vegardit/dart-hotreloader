#!/usr/bin/env bash
# SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com) and contributors
# SPDX-FileContributor: Sebastian Thomschke, Vegard IT GmbH
# SPDX-License-Identifier: Apache-2.0

if [ "$1" == "--help" ]; then
   echo "Executes the test cases of test/hotreloader_test.dart"
   echo
   echo "Usage: $(basename $0)"
   exit 0
fi

set -eux

dart --enable-asserts --enable-vm-service "$(dirname "$0")/../test/hotreloader_test.dart"
