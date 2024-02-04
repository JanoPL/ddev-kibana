#!/usr/bin/env bats

setup() {
    set -u -o pipefail
    TEST_BREW_PREFIX="$(brew --prefix)"
    load "${TEST_BREW_PREFIX}/lib/bats-support/load.bash"
    load "${TEST_BREW_PREFIX}/lib/bats-assert/load.bash"

    export DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )/.."
    export TESTDIR=~/tmp/testddevkibana
    mkdir -p $TESTDIR
    export PROJNAME=testddevkibana
    export DDEV_NON_INTERACTIVE=true
    cd "${TESTDIR}"
}

teardown() {
    set -eu -o pipefail
    cd ${TESTDIR} || ( printf "unable to cd to ${TESTDIR}\n" && exit 1 )
    [ "${TESTDIR}" != "" ] && rm -rf ${TESTDIR}
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

@test "check docker-compose file included in install.yaml" {
    set -eu -o pipefail

       output=$(yq -r '.project_files[4]' < ${DIR}/install.yaml)

       assert_output "./kibana/docker-compose.kibana8.yaml"
}
