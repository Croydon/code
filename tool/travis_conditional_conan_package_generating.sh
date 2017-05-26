#! /bin/bash
# This file checks if we change files, which are important for mass building for Conan packages
# If they changed we are going to trigger a mass building
# We are doing this by updating the submodule in inexor-game/ci-prebuilds invoking thereby Travis/AppVeyor processes

# TODO: support for branches with conan- instead of only master to test mass building of packages easily

# this makes the entire script fail if one commands fail
set -e

# Making sure we NEVER execute anything of this for pull requests as this could be a huge security risk
if [[ "${TRAVIS_PULL_REQUEST}" != false ]]; then
    exit 0
fi

if ! [[ "${TRAVIS_BRANCH}" == "master"]]; then
    exit 0
fi

# Check if important files did change in the last commit
if [[ "$(git diff --name-only HEAD^^ -- dependencies.py)" == "" ]]; then
    exit 0
fi

cd ..
git clone --recursive https://github.com/inexor-game/ci-prebuilds.git "ci-prebuilds"
cd "ci-prebuilds"
git checkout master

git config user.name ${GITHUB_BOT_NAME}
git config user.email ${GITHUB_BOT_EMAIL}

# Update submodule
cd inexor
git pull
git checkout master
cd ../

git add -A
git commit -am "[bot] Updating Conan dependencies!"

git config credential.helper "store --file=.git/credentials"
echo "https://${GITHUB_TOKEN}:@github.com" > .git/credentials

git push
exit 0
