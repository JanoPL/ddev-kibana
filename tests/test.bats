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

    output=$(ddev exec "curl -s --location 'kibana:5601/api/status' --header 'Content-Type: application/json' | jq --raw-output '.status.overall.state'")
    assert_output "green"
}
