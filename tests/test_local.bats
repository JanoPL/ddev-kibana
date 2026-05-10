# This test suite validates the local installation and connectivity of Kibana when running in its latest version mode.
#!/usr/bin/env bats

load "common_setup.bash"

# Sets up environment variables specific to the local kibana project.
setup_file() {
    export PROJNAME="test-kibana-local-dir"
    common_setup_env
}

# Loads common Bats libraries required for assertions and functions.
setup() {
    load_bats_libs
}

# Cleans up the local ddev environment and project resources after testing.
teardown_file() {
    common_teardown_file
}

# Test connectivity to Kibana API when running with the latest version setup.
@test "test_local_when_version_is_latest" { 
    set -eu -o pipefail

    ddev start >/dev/null 2>&1

    # Wait until Kibana is accessible on port 5601 from within ddev container
    ddev exec "timeout 60s bash -c 'until curl -s kibana:5601/api/status > /dev/null; do sleep 2; done'"
    
    output=$(ddev exec "curl -s --location 'kibana:5601/api/status' --header 'Content-Type: application/json' | jq --raw-output '.version.number'")
    assert_output "9.3.3"

    # Check the overall status level exposed via the Kibana API endpoint.
    output=$(ddev exec "curl -s --location 'kibana:5601/api/status' --header 'Content-Type: application/json' | jq --raw-output '.status.overall.level'")
    assert_output "available"
}