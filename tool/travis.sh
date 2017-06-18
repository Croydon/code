#! /bin/bash
#
# Structure
# * Utility functions
# * Compiling and testing
# * Main routine

## UTILITY FUNCTIONS #######################################

# Check if a string contains something
contains() {
  test "`subrm "$1" "$2"`" != "$1"
}

# Remove a substring by name
subrm() {
  echo "${1#*$2}"
}

mkcd() {
  mkdir -pv "$1"
  cd "$1"
}

# Check whether this travis job runs for the main repository
# that is inexor-game/code
is_main_repo() {
  test "${TRAVIS_REPO_SLUG}" = "${main_repo}"
}

# Check whether this build is for a pull request
is_pull_request() {
  test "${TRAVIS_PULL_REQUEST}" != false
}

# Check whether this is a pull request, wants to merge a
# branch within the main repo into the main repo.
#
# E.g. Merge inexor-game/code: karo/unittesting
#      into  inexor-game/code: master
self_pull_request() {
  is_pull_request && is_main_repo
}

# Check whether this is a pull request, that pulls a branch
# from a different repo.
external_pull_request() {
  if is_main_repo; then
    false
  else
    is_pull_request
  fi
}

## increment the version number based on the last tag.
incremented_version()
{
  local major_version=`echo -e "${last_tag}" | sed "s/^\(.*\)\\.[0-9]\+\.[0-9]\+-alpha$/\1/"`
  local minor_version=`echo -e "${last_tag}" | sed "s/^[0-9]\+\.\(.*\)\.[0-9]\+-alpha$/\1/"`
  local patch_version=`echo -e "${last_tag}" | sed "s/^[0-9]\+\.[0-9]\+\.\(.*\)-alpha$/\1/"`


  local new_patch_version=$((patch_version+1))
  local new_version="$major_version.$minor_version.$new_patch_version-alpha"
  echo $new_version
}

# The package.json contains PLACEHOLDERs we need to replace.
# On deploy (so if this is a tagged build), we want to publish to npm as well.
update_package_json()
{
  local package_json_path="${code}/package.json"

  # Cut the "-alpha" from the version
  local package_version=`echo -e "${INEXOR_VERSION}" | sed "s/^\(.*\)-alpha$/\1/"`

  # Replace the version in the file.
  sed -i -e "s/VERSION_PLACEHOLDER/${package_version}/g" "${package_json_path}"

  local package_name_extension="linux64"

  # Make the package name platform specific
  sed -i -e "s/PLATFORM_PLACEHOLDER/${package_name_extension}/g" "${package_json_path}"
}

publish_to_npm()
{
  # Create a npmrc file containing our npm token
  echo "@inexorgame:registry=https://registry.npmjs.org/
//registry.npmjs.org/:_authToken=${NPM_TOKEN}" > .npmrc

  update_package_json
  npm pack
  npm publish --access public
}

# increment version and create a tag on github.
# (each time we push to master)
create_tag() {
  if test -n "$TRAVIS_TAG"; then
    echo >&2 -e "===============\n" \
      "Skipping tag creation, because this build\n" \
      "got triggered by a tag.\n" \
      "===============\n"
  elif [ "$TRAVIS_BRANCH" = "master" -a "$TRAVIS_PULL_REQUEST" = "false" ]; then
    # direct push to master

    export new_version=$(incremented_version)

    git config --global user.email "travis@travis-ci.org"
    git config --global user.name "Travis"

    git tag -a -m "automatic tag creation on push to master branch" "${new_version}"
    git push -q https://$GITHUB_TOKEN@github.com/inexorgame/inexor-core --tags

  else
    echo >&2 -e "===============\n" \
      "Skipping tag creation, because this is \n" \
      "not a direct commit to master.\n" \
      "===============\n"
      export new_version=$(incremented_version)
      echo >&2 -e $new_version
  fi
}


# ACTUALLY COMPILING AND TESTING INEXOR ####################

build() {
  (
    mkcd "/tmp/inexor-build"

    conan --version

    # TODO: FIXME: We need a hardcoded workaround for GCC5.4 to link gtest successfully
    #if [[ $CC == "gcc-5" ]]; then
        #conan install gtest/1.8.0@lasote/stable --build -s compiler="$CONAN_COMPILER" -s compiler.version="$CONAN_COMPILER_VERSION" -s compiler.libcxx="libstdc++11" -e CC="$CC" -e CXX="$CXX"
    #fi

    conan remote add inexor https://api.bintray.com/conan/inexorgame/inexor-conan --insert

    if test "$NIGHTLY" = conan; then
      echo "executed conan install "$gitroot" --scope build_all=1 --build -s compiler=$CONAN_COMPILER -s compiler.version=$CONAN_COMPILER_VERSION -s compiler.libcxx=libstdc++11 -e CC=$CC -e CXX=$CXX"
      conan install "$gitroot" --scope build_all=1 --build -s compiler="$CONAN_COMPILER" -s compiler.version="$CONAN_COMPILER_VERSION" -s compiler.libcxx="libstdc++11" -e CC="$CC" -e CXX="$CXX"
    else
      echo "executed conan install "$gitroot" --scope build_all=1 --scope create_package=1 --build=missing -s compiler=$CONAN_COMPILER -s compiler.version=$CONAN_COMPILER_VERSION -s compiler.libcxx=libstdc++11 -e CC=$CC -e CXX=$CXX"
      conan install "$gitroot" --scope build_all=1 --scope create_package=1 --build=missing -s compiler="$CONAN_COMPILER" -s compiler.version="$CONAN_COMPILER_VERSION" -s     compiler.libcxx="libstdc++11" -e CC="$CC" -e CXX="$CXX"
    fi

    conan build "$gitroot"
  )
}

run_tests() {
  if contains "$TARGET" linux; then
    "${bin}/unit_tests"
  else
    echo >&2 "ERROR: UNKNOWN TRAVIS TARGET: ${TARGET}"
    exit 23
  fi
}

# ATTENTION:
# Please USE the following naming format for any files uploaded to our distribution server
# <BRANCHNAME>-<BUILDNUMBER>-<TARGET_NAME>.EXTENSION
# where <PACKAGENAME> is NOT CONTAINING any -
# correct: master-1043.2-linux_gcc.txt
# correct: refactor-992.2-apidoc.hip
# exception: master-latest-<TARGET_NAME>.zip
# wrong: ...-linux_gcc-1043.2.zip

## UPLOADING NIGHTLY BUILDS AND THE APIDOC #################

# upload remote_path local_path [local_paths]...
#
# Upload one or more files to our nightly or dependencies server
# Variables are defined on the Travis website
upload() {
  # Fix an issue where upload directory gets specified by subsequent upload() calls
  ncftpput -R -v -u "$NIGHTLY_USER" -p "$NIGHTLY_PASSWORD" "$FTP_DOMAIN" / "$@"
}

upload_apidoc() {
  (
    local zipp="/tmp/$build"
    cd "$gitroot" -v
    doxygen doxygen.conf 2>&1 | grep -vF 'sqlite3_step " \
      "failed: memberdef.id_file may not be NULL'
    mv doc "$zipp"
    zip -r "${zipp}.zip" "$zipp"
    upload "$zipp.zip"
  )
}

nigthly_build() {
  local outd="/tmp/${build}.d/"
  local zipf="/tmp/${build}.zip"
  local descf="/tmp/${build}.txt"

  return 0
}

## TARGETS CALLED BY TRAVIS ################################

# Upload nightly
target_after_success() {
  if test "$TARGET" != apidoc; then
    #external_pull_request || nigthly_build || true
    if test "$NIGHTLY" = true; then
        # Upload zip nightly package to our FTP
        nigthly_build
    fi
    if test "$NIGHTLY" = conan; then
        # Upload all conan packages to conan.io
        conan user -p "${NIGHTLY_PASSWORD}" -r inexor "${NIGHTLY_USER}"
        set -f
        conan upload --all --force -r inexor --retry 3 --retry_wait 10 --confirm "*stable*"
        set +f
    fi
  fi
  exit 0
}

# Upload nightly
target_after_deploy() {
  if test "$TARGET" != apidoc; then
    if test -n "$TRAVIS_TAG"; then
      if test "$CC" == "gcc"; then
        publish_to_npm
      fi
    fi
  fi
  exit 0
}

target_script() {
  if test "$TARGET" = apidoc; then
    upload_apidoc
  elif test "$TARGET" = new_version_tagger; then
    create_tag
  else
    build
    run_tests
    target_after_success
  fi
  exit 0
}

## MAIN ####################################################

# this makes the entire script fail if one commands fail
set -e

script="$0"
tool="`dirname "$0"`"
code="${tool}/.."
bin="${code}/bin"
TARGET="$3"
#CMAKE_FLAGS="$4"
CONAN_COMPILER="$4"
CONAN_COMPILER_VERSION="$5"
export CC="$6"
export CXX="$7"

export commit="$8"
export branch="$9" # The branch we're on
export jobno="${10}" # The job number
# Nightly is either true, false or conan
NIGHTLY="${11}"
NIGHTLY_USER="${12}"
NIGHTLY_PASSWORD="${13}"
FTP_DOMAIN="${14}"


# Name of this build
export build="$(echo "${branch}-${jobno}" | sed 's#/#-#g')-${TARGET}"
export main_repo="inexorgame/inexor-core"

# Workaround Boost.Build problem to not be able to found Clang
if [[ $CC == clang* ]]; then
  sudo ln -sf /usr/bin/${CC} /usr/bin/clang
  sudo ln -sf /usr/bin/${CXX} /usr/bin/clang++
fi

# Just to make sure that no package uses the wrong GCC version...
if [[ $CC == gcc* ]]; then
  sudo ln -sf /usr/bin/${CC} /usr/bin/gcc
  sudo ln -sf /usr/bin/${CXX} /usr/bin/gcc++
fi


if [ -z "$2" ]; then
  export gitroot="/inexor"
else
  # this makes it possible to run this script successfull
  # even if doesn't get called from the root directory
  # of THIS repository
  # required to make inexor-game/ci-prebuilds working
  export gitroot="/inexor/$2"
fi

self_pull_request && {
  echo >&2 -e "Skipping build, because this is a pull " \
    "request with a branch in the main repo.\n"         \
    "This means, there should already be a CI job for " \
    "this branch. No need to do things twice."
  exit 0
}

cd "$gitroot"

# Tags do not get fetched from travis usually.
git fetch origin 'refs/tags/*:refs/tags/*'
export last_tag=`git describe --tags $(git rev-list --tags --max-count=1)`


# The tag gets created on push to the master branch, then we push the tag to github and that push triggers travis.
if test -n "$TRAVIS_TAG"; then
  # We use the last tag as version for the package creation if this job got triggered by a tag-push.
  export INEXOR_VERSION=${last_tag}
else
  # Otherwise we want a new version, not the last tag of the master branch, but the last one + 1.
  export INEXOR_VERSION=$(incremented_version)
fi

"$@"  # Call the desired function
