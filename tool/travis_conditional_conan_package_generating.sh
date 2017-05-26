#! /bin/bash
# This file checks if we change files, which are important for mass building for Conan packages
# If they changed we are going to trigger a mass building
# We are doing this by updating the submodule in inexor-game/ci-prebuilds invoking thereby Travis/AppVeyor processes

# TODO: support for branches with conan- instead of only master to test mass building of packages easily

# this makes the entire script fail if one commands fail
set -e

# Making sure we NEVER execute anything of this for pull requests as this could be a huge security risk
if [[ "${TRAVIS_PULL_REQUEST}" != false ]]; then
    echo "We don't build Conan packages for pull requests for security reasons."
    exit 0
fi

# TODO: Change to master
if ! [[ "${TRAVIS_BRANCH}" == "rebased2" ]]; then
    echo "This isn't the master branch"
    exit 0
fi

# Check if important files did change in the last commit
echo "Filtered git diff output:"
echo "$(git diff --name-only HEAD^ -- dependencies.py)"

if [[ "$(git diff --name-only HEAD^ -- dependencies.py)" == "" ]]; then
    echo "No changes found in Conan dependencies!"
    exit 0
fi

echo "Changes found in Conan dependencies!"
echo "Configure git"

cd ..
git clone --recursive https://github.com/inexor-game/ci-prebuilds.git "ci-prebuilds"
cd "ci-prebuilds"
# TODO: Change to master
git checkout trial5

git config user.name ${GITHUB_BOT_NAME}
git config user.email ${GITHUB_BOT_EMAIL}

# Update submodule
echo "Update submodule in ci-prebuilds"
cd inexor
# TODO: change to master
git pull origin rebased2
# TODO: change to master
git checkout rebased2
cd ../

echo "Create a commit"
git add -A
git commit -am "[bot] Updating Conan dependencies!"


git config credential.helper "store --file=.git/credentials"
echo "https://${GITHUB_TOKEN}:@github.com" > .git/credentials

echo "Push commit"
git push

echo "Mass building of Conan packages is on its way!"
exit 0
