#! /bin/bash
#
# ATTENTION:
# Please USE the following naming format for any files uploaded to our distribution server
# <BRANCHNAME>-<BUILDNUMBER>-<TARGET_NAME>.EXTENSION
# where <PACKAGENAME> is NOT CONTAINING any -
# correct: master-1043.2-linux_gcc.txt
# correct: refactor-992.2-apidoc.hip
# exception: master-latest-<TARGET_NAME>.zip
# wrong: ...-linux_gcc-1043.2.zip

## UPLOADING NIGHTLY BUILDS AND THE APIDOC #################

upload_apidoc() {
  (
    local zipp="/tmp/$build"
    cd "$gitroot" -v
    doxygen doxygen.conf 2>&1 | grep -vF 'sqlite3_step " \
      "failed: memberdef.id_file may not be NULL'
    mv doc "$zipp"
    zip -r "${zipp}.zip" "$zipp"
    ./travis_ftp.sh upload "$zipp.zip"
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

  ./travis_ftp.sh "$zipf" "$descf"

  if test "$branch" = master; then (
    ln -s "$zipf" "master-latest-$TARGET.zip"
    ln -s "$descf" "master-latest-$TARGET.txt"
    ./travis_ftp.sh "master-latest-$TARGET.zip" "master-latest-$TARGET.txt"
  ) fi
  
  return 0
}

nigthly_build
