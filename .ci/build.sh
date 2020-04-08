#!/usr/bin/env bash
#
# Copyright 2020 by Vegard IT GmbH, Germany, https://vegardit.com
# SPDX-License-Identifier: Apache-2.0
#
# @author Sebastian Thomschke, Vegard IT GmbH

set -e # abort script at first error
set -o pipefail # causes a pipeline to return the exit status of the last command in the pipe that returned a non-zero return value
set -o nounset # treat undefined variables as errors

if [[ -f .ci/release-trigger.sh ]]; then
    echo "Sourcing [.ci/release-trigger.sh]..."
    source .ci/release-trigger.sh
fi

cd $(dirname $0)/..

echo "###########################################################"
echo "# Testing Dart Library Package...                         #"
echo "###########################################################"
echo " -> GIT Branch: $GIT_BRANCH"
projectVersion="$(grep "version: " pubspec.yaml | cut -f2 -d" ")"
echo " -> Current Version: $projectVersion"

echo "|---------------------------------------------------------|"
echo "| Checking source code style...                           |"
echo "|---------------------------------------------------------|"
bash tool/checkstyle.sh

echo "|---------------------------------------------------------|"
echo "| Running tests with minimum versions of dependencies...  |"
echo "|---------------------------------------------------------|"
pub downgrade
bash tool/test.sh

echo "|---------------------------------------------------------|"
echo "| Running tests with maximum versions of dependencies...  |"
echo "|---------------------------------------------------------|"
pub upgrade
bash tool/test.sh

#
# decide whether to build/deploy a snapshot version or perform a release build
#
if [[ ${MAY_CREATE_RELEASE:-false} = "true" && ${projectVersion:-foo} == ${RELEASE_VERSION:-bar} ]]; then
   echo "###########################################################"
   echo "# Creating Dart Library Package Release...                #"
   echo "###########################################################"

   cat <<EOF > ~/.pub-cache/credentials.json
{
  "accessToken":"$PUBDEV_ACCESS_TOKEN",
  "refreshToken":"$PUBDEV_REFRESH_TOKEN",
  "tokenEndpoint":"https://accounts.google.com/o/oauth2/token",
  "scopes":["https://www.googleapis.com/auth/userinfo.email","openid"],
  "expiration":$PUBDEV_TOKEN_EXPIRATION
}
EOF

   pub publish --dry-run

   git tag $RELEASE_VERSION

   # as workaround for https://dart.dev/tools/pub/publishing#what-files-are-published
   # we temporarily remove files from the index we don't want to be part of the published package
   for exclude in .ci .travis.yml test tool; do
      git rm -r --cached $exclude
      echo "$exclude" >> .gitignore
   done

   pub publish --force

   # restore files
   git reset --hard

   sed -i "s/version: $projectVersion/version: $NEXT_DEV_VERSION/" pubspec.yaml
   git commit -m "Bump version from $RELEASE_VERSION to $NEXT_DEV_VERSION" pubspec.yaml

   git push origin HEAD:$GIT_BRANCH
   git push --tags
fi
