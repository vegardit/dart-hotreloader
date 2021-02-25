#!/usr/bin/env bash
# Copyright 2020-2021 by Vegard IT GmbH (https://vegardit.com) and contributors.
# SPDX-License-Identifier: Apache-2.0
#
# @author Sebastian Thomschke, Vegard IT GmbH

if [ "$1" == "--help" ]; then
   echo "Checks the source code against coding guidelines."
   echo
   echo "Usage: $(basename $0)"
   exit 0
fi

if dart analyze --help &>/dev/null; then
   dart analyze --fatal-warnings $(dirname $0)/../lib
   dart analyze --fatal-warnings $(dirname $0)/../test
else
   dartanalyzer \
      --lints \
      --fatal-warnings \
      --options $(dirname $0)/../analysis_options.yaml \
      $(dirname $0)/../lib \
      $(dirname $0)/../test
fi
