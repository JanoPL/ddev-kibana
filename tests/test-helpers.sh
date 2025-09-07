#!/bin/env bash

# Test helper functions for BATS tests

# Check if required commands are available
check_prerequisites() {
    local missing_commands=()
    
    for cmd in yq jq; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [ ${#missing_commands[@]} -gt 0 ]; then
        echo "Missing required commands: ${missing_commands[*]}"
        echo "Please install them before running tests"
        return 1
    fi
}

# Setup function that runs before each test
setup_test_environment() {
    # Ensure we have required tools
    check_prerequisites || skip "Missing prerequisites"
    
    # Set default test environment variables
    export DDEV_PRIMARY_URL="${DDEV_PRIMARY_URL:-https://test.ddev.site}"
    export DDEV_PROJECT_NAME="${DDEV_PROJECT_NAME:-test-project}"
}

# Helper to create a minimal valid Kibana config
create_minimal_valid_config() {
    local config_file="$1"
    cat > "$config_file" << EOF
server.host: "0.0.0.0"
server.port: 5601
elasticsearch.hosts: ["http://elasticsearch:9200"]
EOF
}

# Helper to create an invalid YAML config
create_invalid_yaml_config() {
    local config_file="$1"
    cat > "$config_file" << EOF
server.host: "0.0.0.0"
invalid_yaml: [unclosed_bracket
elasticsearch.hosts: ["http://elasticsearch:9200"
EOF
}

# Helper to count files matching a pattern
count_files() {
    local pattern="$1"
    find . -name "$pattern" 2>/dev/null | wc -l
}

# Helper to wait for a condition with timeout
wait_for_condition() {
    local condition="$1"
    local timeout="${2:-10}"
    local interval="${3:-1}"
    local elapsed=0
    
    while [ $elapsed -lt $timeout ]; do
        if eval "$condition"; then
            return 0
        fi
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done
    
    return 1
}

# Helper to generate a random string
generate_random_string() {
    local length="${1:-32}"
    openssl rand -base64 "$length" | tr -d "=+/" | cut -c1-"$length"
}

# Helper to check if string is valid YAML
is_valid_yaml() {
    local file="$1"
    yq eval '.' "$file" >/dev/null 2>&1
}

# Helper to extract value from YAML file
get_yaml_value() {
    local file="$1"
    local key="$2"
    yq eval ".\"$key\"" "$file" 2>/dev/null
}

# Common setup for configuration management tests
setup_config_test_env() {
    setup_test_environment
    
    # Additional setup specific to config tests
    export CONFIG_TEST_MODE=1
}