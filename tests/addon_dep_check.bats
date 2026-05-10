#!/usr/bin/env bats

load "common_setup.bash"

setup_file() {
    export PROJNAME="test-kibana-general"
    common_setup_env_basic
}

setup() {
    load_bats_libs
}

teardown() {
    common_teardown_file
}

@test "install from directory without elasticsearch dependency" {
    set -eu pipefail

    run ddev add-on get ${DIR}
    assert_success
}