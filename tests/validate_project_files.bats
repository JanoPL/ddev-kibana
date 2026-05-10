#!/usr/bin/env bats

load "common_setup.bash"

setup() {
    export PROJNAME="test-kibana-general"
    load_bats_libs
    common_prepare_dir
}

teardown() {
    common_teardown_file
}

@test "check docker file included in install.yaml" {
   set -eu -o pipefail

   output=$(yq -r '.project_files[2]' < ${DIR}/install.yaml)

   assert_output "./kibana/Dockerfile"
}

@test "check healthcheck file included in install.yaml" {
   set -eu -o pipefail

   output=$(yq -r '.project_files[3]' < ${DIR}/install.yaml)

   assert_output "./kibana/healthcheck.sh"
}

@test "check config file included in install.yaml" {
    set -eu -o pipefail

    output=$(yq -r '.project_files[1]' < ${DIR}/install.yaml)

    assert_output "./kibana/config.yml"
}
