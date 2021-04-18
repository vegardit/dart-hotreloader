#!/usr/bin/env bash
# Copyright 2020-2021 by Vegard IT GmbH (https://vegardit.com) and contributors.
# SPDX-License-Identifier: Apache-2.0
#
# @author Sebastian Thomschke, Vegard IT GmbH

if [ "$1" == "--help" ]; then
   echo "Formats the source code."
   echo
   echo "Usage: $(basename $0)"
   exit 0
fi

set -eux

dart format --line-length 120 $(dirname $0)/../lib
dart format --line-length 120 $(dirname $0)/../test
