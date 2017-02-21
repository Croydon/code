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


# ACTUALLY COMPILING AND TESTING INEXOR ####################

build() {
  (
    mkcd "/tmp/inexor-build-${build}"
    #conan
    echo "executed conan install "$gitroot" --scope build_all=1 --build=missing -s compiler=$CONAN_COMPILER -s compiler.version=$CONAN_COMPILER_VERSION -s compiler.libcxx=libstdc++11"
    conan install "$gitroot" --scope build_all=1 --build=missing -s compiler="$CONAN_COMPILER" -s compiler.version="$CONAN_COMPILER_VERSION" -s compiler.libcxx="libstdc++11" -e CC="$CC" -e CXX="$CXX"
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
  ncftpput -R -v -u "$FTP_USER" -p "$FTP_PASSWORD" "$FTP_DOMAIN" / "$@"
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

  # Include the media files
  local media="${media}"
  test -n "${media}" || test "$branch" = master && media=true

  echo "
  ---------------------------------------
    Exporting Nightly build

    commit: ${commit}
    branch: ${branch}
    job:    ${jobno}
    build:  ${build}

    gitroot: ${gitroot}
    zip: ${zipf}
    dir: ${outd}

    data export: $media
  "

  mkdir "$outd"

  if test "$media" = true; then (
    cd "$gitroot"
    curl -LOk https://github.com/inexor-game/data/archive/master.zip
    unzip "master.zip" -d "$outd"
    rm "master.zip"
    cd "$outd"
    mv "data-master" "media/data"
  ) fi

  local ignore="$(<<< '
    .
    ..
    .gitignore
    build
    cmake
    CMakeLists.txt
    appveyor.yml
    doxygen.conf
    .git
    .gitignore
    .gitmodules
    inexor
    platform
    tool
    vendor
    .travis.yml
  ' tr -d " " | grep -v '^\s*$')"

  (
    cd "$gitroot"
    ls -a | grep -Fivx "$ignore" | xargs -t cp -rvt "$outd"
  )

  (
    cd "`dirname "$outd"`"
    zip -r "$zipf" "`basename $outd`"
  )

  (
    echo "Commit: ${commit}"
    echo -n "SHA 512: "
    sha512sum "$zipf"
  ) > "$descf"

  upload "$zipf" "$descf"

  if test "$branch" = master; then (
    ln -s "$zipf" "master-latest-$TARGET.zip"
    ln -s "$descf" "master-latest-$TARGET.txt"
    upload "master-latest-$TARGET.zip" "master-latest-$TARGET.txt"
  ) fi
  
  return 0
}

## TARGETS CALLED BY TRAVIS ################################


# Upload nightly
target_after_success() {
  if test "$TARGET" != apidoc; then
    external_pull_request || nigthly_build || true
  fi
  exit 0
}

target_script() {
  if test "$TARGET" = apidoc; then
    upload_apidoc
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

export main_repo="inexor-game/code"
export branch="$TRAVIS_BRANCH" # The branch we're on
export jobno="$TRAVIS_JOB_NUMBER" # The job number
export commit="${TRAVIS_COMMIT}"
# Name of this build
export build="$(echo "${branch}-${jobno}" | sed 's#/#-#g')-${TARGET}"
#export gitroot="$TRAVIS_BUILD_DIR"

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
"$@"  # Call the desired function
