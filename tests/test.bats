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
    ddev delete -Oy ${PROJNAME} >/dev/null 2>&1 || true
    cd "${TESTDIR}"
    ddev config --project-name=${PROJNAME}
    ddev start -y >/dev/null 2>&1
}

teardown() {
    set -eu -o pipefail
    cd ${TESTDIR} || ( printf "unable to cd to ${TESTDIR}\n" && exit 1 )
    ddev delete -Oy ${PROJNAME} >/dev/null 2>&1
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

@test "install from directory" {
    set -eu -o pipefail

    cd ${TESTDIR} || ( printf "unable to cd to ${TESTDIR}\n" && exit 1 )
    echo "# ddev get ${DIR} with project ${PROJNAME} in ${TESTDIR} ($(pwd))" >&3

    ddev get ddev/ddev-elasticsearch
    ddev get ${DIR}
    ddev restart >/dev/null 2>&1
    ddev logs -s kibana >&3

    output=$(ddev exec "curl -s --location 'kibana:5601/api/status' --header 'Content-Type: application/json' | jq --raw-output '.status.overall.state'")
    assert_output "green"
}

@test "install from directory without elasticsearch dependency" {
    set -eu -o pipefail

    cd ${TESTDIR} || ( printf "unable to cd to ${TESTDIR}\n" && exit 1 )
    echo "# ddev get ${DIR} with project ${PROJNAME} in ${TESTDIR} ($(pwd))" >&3

    ddev get ddev/ddev-adminer
    run ddev get ${DIR}
    run assert_failure
}

@test "install from release" {
    set -eu -o pipefail

    cd ${TESTDIR} || ( printf "unable to cd to ${TESTDIR}\n" && exit 1 )
    echo "# ddev get JanoPL/ddev-kibana with project ${PROJNAME} in ${TESTDIR} ($(pwd))" >&3

    ddev get ddev/ddev-elasticsearch
    ddev get JanoPL/ddev-kibana
    ddev restart >/dev/null 2>&1
    ddev logs -s kibana >&3

    output=$(ddev exec "curl -s --location 'kibana:5601/api/status' --header 'Content-Type: application/json' | jq --raw-output '.status.overall.state'")
    assert_output "green"
}

@test "install different version of kibana from directory" {
    set -eu -o pipefail

    cd ${TESTDIR} || ( printf "unable to cd to ${TESTDIR}\n" && exit 1 )
    echo "# ddev get ${DIR} with project ${PROJNAME} in ${TESTDIR} ($(pwd))" >&3

    ddev get ddev/ddev-elasticsearch
    cp .ddev/elasticsearch/docker-compose.elasticsearch8.yaml .ddev/
    ddev get ${DIR}

    yq --version >&3
    yq -e -i '.services.kibana.build.args[0] = "KIBANA_VERSION=8.10.2"' ./.ddev/docker-compose.kibana.yaml
    yq -e -i '.services.kibana.environment.KIBANA_VERSION = "8.10.2"' ./.ddev/docker-compose.kibana.yaml

    ddev restart >/dev/null 2>&1
    ddev logs -s kibana >&3

    output=$(ddev exec "curl -s --location 'kibana:5601/api/status' --header 'Content-Type: application/json' | jq --raw-output '.version.number'")
    assert_output "8.10.2"

    output=$(ddev exec "curl -s --location 'kibana:5601/api/status' --header 'Content-Type: application/json' | jq --raw-output '.status.overall.level'")
    assert_output "available"
}
