#!/usr/bin/env bash
# SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com) and contributors
# SPDX-FileContributor: Sebastian Thomschke, Vegard IT GmbH
# SPDX-License-Identifier: Apache-2.0

set -e # abort script at first error
set -o pipefail # causes a pipeline to return the exit status of the last command in the pipe that returned a non-zero return value
set -o nounset # treat undefined variables as errors

if [[ -f .ci/release-trigger.sh ]]; then
   echo "Sourcing [.ci/release-trigger.sh]..."
   source .ci/release-trigger.sh
fi

cd $(dirname $0)/..

echo
echo "###################################################"
echo "# Determining GIT branch......                    #"
echo "###################################################"
GIT_BRANCH=$(git branch --show-current)
echo "  -> GIT Branch: $GIT_BRANCH"; echo

echo "###########################################################"
echo "# Testing Dart Library Package...                         #"
echo "###########################################################"
echo " -> GIT Branch: $GIT_BRANCH"
projectVersion="$(grep "version: " pubspec.yaml | cut -f2 -d" ")"
echo " -> Current Version: $projectVersion"
echo " -> Release Version: $RELEASE_VERSION"

dart pub get


echo "|---------------------------------------------------------|"
echo "| Checking source code style...                           |"
echo "|---------------------------------------------------------|"
bash tool/checkstyle.sh


echo "|---------------------------------------------------------|"
echo "| Running tests with minimum versions of dependencies...  |"
echo "|---------------------------------------------------------|"
dart pub downgrade
bash tool/test.sh


echo "|---------------------------------------------------------|"
echo "| Running tests with maximum versions of dependencies...  |"
echo "|---------------------------------------------------------|"
dart pub upgrade
bash tool/test.sh

#
# decide whether to build/deploy a snapshot version or perform a release build
#
if [[ ${MAY_CREATE_RELEASE:-false} == "true" && ${projectVersion:-foo} == ${RELEASE_VERSION:-bar} ]]; then
   echo "###########################################################"
   echo "# Creating Dart Library Package Release...                #"
   echo "###########################################################"

   set -x
   dart pub publish --dry-run

   git tag $RELEASE_VERSION
   git push --tags # this triggers the publish.yml workflow

   sed -i "s/version: $projectVersion/version: $NEXT_DEV_VERSION/" pubspec.yaml
   git commit -m "Bump version from $RELEASE_VERSION to $NEXT_DEV_VERSION" pubspec.yaml

   git push origin HEAD:$GIT_BRANCH
   set +x
fi
