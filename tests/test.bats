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

# Helper function to wait for Kibana to be ready
wait_for_kibana() {
    local timeout=120
    local elapsed=0
    local interval=3

    echo "Waiting for Kibana to be ready..." >&3
    while [ $elapsed -lt $timeout ]; do
        # Check if kibana service exists and is responding
        if ddev exec "curl -s --connect-timeout 5 --max-time 10 'kibana:5601/api/status' 2>/dev/null | jq -r '.status.overall.state' 2>/dev/null" | grep -q "green"; then
            echo "Kibana is ready after ${elapsed}s" >&3
            return 0
        fi
        sleep $interval
        elapsed=$((elapsed + interval))
        echo "Waiting... ${elapsed}/${timeout}s" >&3
    done

    echo "Kibana failed to become ready within ${timeout}s" >&3
    echo "Kibana logs:" >&3
    ddev logs -s kibana --tail=20 >&3 || true
    return 1
}

# Helper function to verify Kibana service exists
verify_kibana_service() {
    ddev describe | grep -q "kibana"
    ddev describe | grep -q "5601"
}

@test "install from directory" {
    set -eu -o pipefail

    cd ${TESTDIR} || ( printf "unable to cd to ${TESTDIR}\n" && exit 1 )
    echo "# ddev add-on get ${DIR} with project ${PROJNAME} in ${TESTDIR} ($(pwd))" >&3

    # Install dependencies first
    run ddev add-on get ddev/ddev-elasticsearch
    assert_success

    # Install Kibana add-on
    run ddev add-on get ${DIR}
    assert_success

    # Restart and wait for services
    run ddev restart
    assert_success

    # Verify service is present
    run verify_kibana_service
    assert_success

    # Wait for Kibana to be ready
    run wait_for_kibana
    assert_success

    # Test Kibana status
    run ddev exec "curl -s --location 'kibana:5601/api/status' --header 'Content-Type: application/json' | jq --raw-output '.status.overall.state'"
    assert_success
    assert_output "green"
}

@test "install from directory without elasticsearch dependency" {
    set -eu -o pipefail

    cd ${TESTDIR} || ( printf "unable to cd to ${TESTDIR}\n" && exit 1 )
    echo "# Testing Kibana installation without Elasticsearch dependency" >&3

    # Install a different add-on to ensure we don't have elasticsearch
    run ddev add-on get ddev/ddev-adminer
    assert_success

    # Try to install Kibana without elasticsearch - should fail
    run ddev add-on get ${DIR}
    assert_failure
}

@test "install from release" {
    set -eu -o pipefail

    cd ${TESTDIR} || ( printf "unable to cd to ${TESTDIR}\n" && exit 1 )
    echo "# ddev add-on get JanoPL/ddev-kibana with project ${PROJNAME} in ${TESTDIR} ($(pwd))" >&3

    # Install dependencies first
    run ddev add-on get ddev/ddev-elasticsearch
    assert_success

    # Install from release
    run ddev add-on get JanoPL/ddev-kibana
    assert_success

    run ddev restart
    assert_success

    # Verify service
    run verify_kibana_service
    assert_success

    # Wait for services and test
    run wait_for_kibana
    assert_success

    run ddev exec "curl -s --location 'kibana:5601/api/status' --header 'Content-Type: application/json' | jq --raw-output '.status.overall.state'"
    assert_success
    assert_output "green"
}

@test "kibana configuration files are created" {
    set -eu -o pipefail

    cd ${TESTDIR} || ( printf "unable to cd to ${TESTDIR}\n" && exit 1 )

    run ddev add-on get ddev/ddev-elasticsearch
    assert_success

    run ddev add-on get ${DIR}
    assert_success

    # Check that configuration files exist
    [ -f .ddev/docker-compose.kibana.yaml ]
    [ -d .ddev/kibana ]
    [ -f .ddev/kibana/config-manager.sh ]
    [ -x .ddev/kibana/config-manager.sh ]
}

@test "kibana configuration manager works" {
    set -eu -o pipefail

    cd ${TESTDIR} || ( printf "unable to cd to ${TESTDIR}\n" && exit 1 )

    run ddev add-on get ddev/ddev-elasticsearch
    assert_success

    run ddev add-on get ${DIR}
    assert_success

    # Test config manager help
    run .ddev/kibana/config-manager.sh
    assert_success
    assert_output --partial "DDEV Kibana Configuration Manager"

    # Test config generation
    run .ddev/kibana/config-manager.sh generate development
    assert_success
    assert_output --partial "Configuration generated"

    # Verify config file was created
    [ -f .ddev/kibana/config.yml ]

    # Test validation
    run .ddev/kibana/config-manager.sh validate
    assert_success
}

@test "install different version of kibana from directory" {
    set -eu -o pipefail

    cd ${TESTDIR} || ( printf "unable to cd to ${TESTDIR}\n" && exit 1 )
    echo "# Testing custom Kibana version installation" >&3

    # Prerequisites check
    if ! command -v yq >/dev/null 2>&1; then
        skip "yq is required for this test"
    fi

    run ddev add-on get ddev/ddev-elasticsearch
    assert_success

    # Copy elasticsearch 8.x config
    cp .ddev/elasticsearch/docker-compose.elasticsearch8.yaml .ddev/

    run ddev add-on get ${DIR}
    assert_success

    # Verify the YAML files exist before modification
    [ -f .ddev/docker-compose.kibana.yaml ]

    # Modify Kibana version
    run yq -e -i '.services.kibana.build.args[0] = "KIBANA_VERSION=8.10.2"' ./.ddev/docker-compose.kibana.yaml
    assert_success

    run yq -e -i '.services.kibana.environment.KIBANA_VERSION = "8.10.2"' ./.ddev/docker-compose.kibana.yaml
    assert_success

    run ddev restart
    assert_success

    # Wait for services
    run wait_for_kibana
    assert_success

    # Test version
    run ddev exec "curl -s --location 'kibana:5601/api/status' --header 'Content-Type: application/json' | jq --raw-output '.version.number'"
    assert_success
    assert_output "8.10.2"

    # Test status
    run ddev exec "curl -s --location 'kibana:5601/api/status' --header 'Content-Type: application/json' | jq --raw-output '.status.overall.level'"
    assert_success
    assert_output "available"
}

@test "install different version of kibana by copy docker compose file" {
    set -eu -o pipefail

    cd ${TESTDIR} || ( printf "unable to cd to ${TESTDIR}\n" && exit 1 )
    echo "# Testing Kibana 8.x installation using pre-built compose file" >&3

    run ddev add-on get ddev/ddev-elasticsearch
    assert_success

    cp .ddev/elasticsearch/docker-compose.elasticsearch8.yaml .ddev/

    run ddev add-on get ${DIR}
    assert_success

    # Use pre-built Kibana 8.x compose file if it exists
    if [ -f .ddev/kibana/docker-compose.kibana8.yaml ]; then
        cp .ddev/kibana/docker-compose.kibana8.yaml .ddev/
    else
        skip "docker-compose.kibana8.yaml not found"
    fi

    run ddev restart
    assert_success

    # Wait for services
    run wait_for_kibana
    assert_success

    # Test version
    run ddev exec "curl -s --location 'kibana:5601/api/status' --header 'Content-Type: application/json' | jq --raw-output '.version.number'"
    assert_success
    assert_output "8.10.2"

    # Test status
    run ddev exec "curl -s --location 'kibana:5601/api/status' --header 'Content-Type: application/json' | jq --raw-output '.status.overall.level'"
    assert_success
    assert_output "available"
}

@test "kibana web interface is accessible" {
    set -eu -o pipefail

    cd ${TESTDIR} || ( printf "unable to cd to ${TESTDIR}\n" && exit 1 )

    run ddev add-on get ddev/ddev-elasticsearch
    assert_success

    run ddev add-on get ${DIR}
    assert_success

    run ddev restart
    assert_success

    run wait_for_kibana
    assert_success

    # Test web interface accessibility
    run ddev exec "curl -s -o /dev/null -w '%{http_code}' kibana:5601"
    assert_success
    assert_output "200"
}

@test "kibana connects to elasticsearch" {
    set -eu -o pipefail

    cd ${TESTDIR} || ( printf "unable to cd to ${TESTDIR}\n" && exit 1 )

    run ddev add-on get ddev/ddev-elasticsearch
    assert_success

    run ddev add-on get ${DIR}
    assert_success

    run ddev restart
    assert_success

    run wait_for_kibana
    assert_success

    # Check elasticsearch connectivity through Kibana
    run ddev exec "curl -s 'kibana:5601/api/status' | jq -r '.status.plugins.elasticsearch.state'"
    assert_success
    assert_output "green"
}

@test "configuration templates exist and are valid" {
    set -eu -o pipefail

    cd ${TESTDIR} || ( printf "unable to cd to ${TESTDIR}\n" && exit 1 )

    run ddev add-on get ddev/ddev-elasticsearch
    assert_success

    run ddev add-on get ${DIR}
    assert_success

    # Check that template files exist
    [ -f .ddev/kibana/templates/config.development.yml ]
    [ -f .ddev/kibana/templates/config.production.yml ]
    [ -f .ddev/kibana/templates/config.testing.yml ]

    # Verify templates are valid YAML (if yq is available)
    if command -v yq >/dev/null 2>&1; then
        run yq eval '.' .ddev/kibana/templates/config.development.yml
        assert_success

        run yq eval '.' .ddev/kibana/templates/config.production.yml
        assert_success

        run yq eval '.' .ddev/kibana/templates/config.testing.yml
        assert_success
    fi
}