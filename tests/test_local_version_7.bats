#!/usr/bin/env bats

load "common_setup.bash"

setup_file() {
    export PROJNAME="test-kibana-local-dir-7"
    common_setup_env
}

setup() {
    load_bats_libs
}

teardown_file() {
    common_teardown_file
}


@test "test_local_when_version_is_7_17_14" {
    set -euo pipefail

    cp .ddev/elasticsearch/docker-compose.elasticsearch7.yaml .ddev/
    
    yq --version >&3
    yq -e -i '.services.kibana.build.args[0] = "KIBANA_VERSION=7.17.14"' ./.ddev/docker-compose.kibana.yaml
    yq -e -i '.services.kibana.environment.KIBANA_VERSION = "7.17.14"' ./.ddev/docker-compose.kibana.yaml

    ddev start >/dev/null 2>&1
    
    ddev exec "timeout 60s bash -c 'until curl -s kibana:5601/api/status > /dev/null; do sleep 2; done'"

    output=$(ddev exec "curl -s --location 'kibana:5601/api/status' --header 'Content-Type: application/json' | jq --raw-output '.version.number'")
    assert_output "7.17.14"

    output=$(ddev exec "curl -s --location 'kibana:5601/api/status' --header 'Content-Type: application/json' | jq --raw-output '.status.overall.state'")
    assert_output "green"
}