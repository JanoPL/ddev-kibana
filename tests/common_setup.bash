#!/usr/bin/env bash

load_bats_libs() {
  if command -v brew >/dev/null 2>&1; then
          local BREW_PREFIX
          BREW_PREFIX="$(brew --prefix)"
          load "${BREW_PREFIX}/lib/bats-support/load.bash"
          load "${BREW_PREFIX}/lib/bats-assert/load.bash"
      else
          load "/usr/lib/bats-support/load.bash"
          load "/usr/lib/bats-assert/load.bash"
      fi
}

common_teardown_file() {
    if [ -n "${TESTDIR:-}" ]; then
        cd "$TESTDIR" && ddev delete -Oy "$PROJNAME" >/dev/null 2>&1
        rm -rf "$TESTDIR"
    fi
}

common_prepare_dir() {
    export PROJNAME="${PROJNAME:-testddevkibana}"
    export TESTDIR="${HOME}/tmp/${PROJNAME}"
    export DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )/.."
    export DDEV_NON_INTERACTIVE=true
    mkdir -p "$TESTDIR"
}

common_setup_env_basic() {
  common_prepare_dir
  cd "$TESTDIR" || exit 1
  ddev delete -Oy "$PROJNAME" >/dev/null 2>&1 || true
  ddev config --project-name="$PROJNAME" --omit-containers db
}

common_setup_env() {
    common_setup_env_basic
    
    ddev add-on get ddev/ddev-elasticsearch >/dev/null
    ddev add-on get "${DIR}" >/dev/null
}

common_setup_env_release() {
  common_setup_env_basic
  
  ddev add-on get ddev/ddev-elasticsearch >/dev/null
  ddev add-on get janopl/ddev-kibana >/dev/null

}