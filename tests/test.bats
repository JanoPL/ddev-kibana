#!/usr/bin/env bats
# Regression test suite for validating Kibana connectivity when using the latest release version.

load "common_setup.bash"

# Sets up the environment for regression tests by initializing a specific project name and loading the release setup.
setup_file() {
	export GITHUB_REPO=janopl/ddev-kibana
    export PROJNAME="test-kibana-regression"
  	export DDEV_NONINTERACTIVE=true
  	export DDEV_NO_INSTRUMENTATION=true

	  common_setup_env_basic
	  load_bats_libs

    ddev add-on get ddev/ddev-elasticsearch >/dev/null
  	ddev add-on get janopl/ddev-kibana >/dev/null
}

# Loads necessary Bats libraries before running tests.
setup() {
    load_bats_libs
}

# Cleans up the DDEV environment after all tests are complete.
teardown_file() {
    common_teardown_file
}

teardown() {
	if [ -n "${GITHUB_ENV:-}" ]; then
    	[ -e "${GITHUB_ENV:-}" ] && echo "TESTDIR=${HOME}/tmp/${PROJNAME}" >> "${GITHUB_ENV}"
  	else
    	[ "${TESTDIR}" != "" ] && rm -rf "${TESTDIR}"
  	fi
}

@test "test_when_release_version_is_latest" {
    set -eu -o pipefail

    # Start ddev services in the background and suppress output.
    ddev start >/dev/null 2>&1

    # Wait for Kibana to become reachable at port 5601.
    ddev exec "timeout 60s bash -c 'until curl -s kibana:5601/api/status > /dev/null; do sleep 2; done'"

    # Check the API status endpoint and ensure the overall level is 'available'.
    output=$(ddev exec "curl -s --location 'kibana:5601/api/status' --header 'Content-Type: application/json' | jq --raw-output '.status.overall.level'")
    assert_output "available"
}
