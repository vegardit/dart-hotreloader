#!/usr/bin/env bash
# SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com) and contributors
# SPDX-FileContributor: Sebastian Thomschke, Vegard IT GmbH
# SPDX-License-Identifier: Apache-2.0

if [ "$1" == "--help" ]; then
   echo "Runs the application in development mode with hot reload enabled."
   echo
   echo "Usage: $(basename $0) [--parameter=value]..."
   exit 0
fi

cwd=$PWD
cd $(dirname "$0")..
pub get
cd  $cwd

dart --version
dart --enable-asserts --enable-vm-service $(dirname "$0")../bin/main_dev.dart "$@"
