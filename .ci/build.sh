#!/usr/bin/env bash
# SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com) and contributors
# SPDX-FileContributor: Sebastian Thomschke, Vegard IT GmbH
# SPDX-License-Identifier: Apache-2.0

#####################
# Script init
#####################
set -eu

# execute script with bash if loaded with other shell interpreter
if [ -z "${BASH_VERSINFO:-}" ]; then /usr/bin/env bash "$0" "$@"; exit; fi

set -o pipefail # causes a pipeline to return the exit status of the last command in the pipe that returned a non-zero return value
set -o nounset # treat undefined variables as errors

# configure stack trace reporting
trap 'rc=$?; echo >&2 "$(date +%H:%M:%S) Error - exited with status $rc in [$BASH_SOURCE] at line $LINENO:"; cat -n $BASH_SOURCE | tail -n+$((LINENO - 3)) | head -n7' ERR

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"


#####################
# Main
#####################
cd "$SCRIPT_DIR/.."

if [[ -f .ci/release-trigger.sh ]]; then
   echo "Sourcing [.ci/release-trigger.sh]..."
   source .ci/release-trigger.sh
fi


echo
echo "###################################################"
echo "# Determining GIT branch......                    #"
echo "###################################################"
GIT_BRANCH=$(git branch --show-current)
echo "  -> GIT Branch: $GIT_BRANCH"


echo
echo "###########################################################"
echo "# Testing Dart Library Package...                         #"
echo "###########################################################"
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
