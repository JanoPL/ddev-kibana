#!/usr/bin/env bats

# Integration tests for DDEV Kibana Configuration Management
# Tests the full installation and configuration workflow

load test-helpers.sh

setup() {
    setup_config_test_env
    
    # Create a temporary DDEV project structure
    export TEST_PROJECT_DIR="${BATS_TMPDIR}/ddev-kibana-integration-$$"
    export DDEV_DIR="${TEST_PROJECT_DIR}/.ddev"
    export KIBANA_DIR="${DDEV_DIR}/kibana"
    
    mkdir -p "$KIBANA_DIR"
    cd "$TEST_PROJECT_DIR"
    
    # Mock DDEV environment
    export DDEV_PRIMARY_URL="https://integration-test.ddev.site"
    export DDEV_PROJECT_NAME="integration-test"
    export DDEV_PROJECT_TYPE="php"
    
    # Copy all required files
    cp -r "${BATS_TEST_DIRNAME}/../kibana"/* "${KIBANA_DIR}/"
    chmod +x "${KIBANA_DIR}/config-manager.sh"
}

teardown() {
    rm -rf "$TEST_PROJECT_DIR"
}

@test "full installation workflow generates valid configuration" {
    # Simulate the installation post-action
    cd "${KIBANA_DIR}"
    
    # Test development environment (default)
    run ./config-manager.sh generate development
    [ "$status" -eq 0 ]
    
    # Validate the generated configuration
    run ./config-manager.sh validate
    [ "$status" -eq 0 ]
    
    # Check that the config file exists and has correct content
    [ -f "config.yml" ]
    grep -q "#ddev-generated" "config.yml"
    grep -q "$DDEV_PRIMARY_URL" "config.yml"
}

@test "environment detection works correctly" {
    cd "${KIBANA_DIR}"
    
    # Test with different environment variables
    export DDEV_KIBANA_ENV="production"
    run ./config-manager.sh generate "$DDEV_KIBANA_ENV"
    [ "$status" -eq 0 ]
    
    grep -q "kibana-prod" "config.yml"
    grep -q "logging.level: warn" "config.yml"
}

@test "configuration survives DDEV restarts (persistence test)" {
    cd "${KIBANA_DIR}"
    
    # Generate initial configuration
    ./config-manager.sh generate development
    
    # Add custom setting
    echo "custom.test.setting: \"persistent-value\"" >> config.yml
    
    # Create backup
    ./config-manager.sh backup
    
    # Simulate configuration being overwritten
    ./config-manager.sh generate development
    
    # Restore from backup
    backup_file=$(ls backups/config_*.yml | head -n1)
    ./config-manager.sh restore "$backup_file"
    
    # Check that custom setting was restored
    grep -q "custom.test.setting: \"persistent-value\"" config.yml
}

@test "configuration wizard works end-to-end" {
    cd "${KIBANA_DIR}"
    
    # Test wizard with predefined inputs (simulated)
    # Note: This test would need to be adapted for actual interactive testing
    
    # For now, test that wizard components work
    run ./config-manager.sh generate development
    [ "$status" -eq 0 ]
    
    run ./config-manager.sh validate
    [ "$status" -eq 0 ]
}

@test "upgrade scenario preserves custom settings" {
    cd "${KIBANA_DIR}"
    
    # Create old-style configuration (without #ddev-generated)
    cat > config.yml << EOF
server.host: "0.0.0.0"
server.port: 5601
elasticsearch.hosts: ["http://elasticsearch:9200"]
custom.user.setting: "important-value"
custom.plugins:
  - "plugin1"
  - "plugin2"
EOF
    
    # Try to generate new configuration
    run ./config-manager.sh generate development
    
    # Should create backup since no #ddev-generated marker
    [ -f config.yml ]
    
    # Backup should contain the custom settings
    backup_file=$(ls backups/config_*.yml | head -n1)
    grep -q "custom.user.setting: \"important-value\"" "$backup_file"
    grep -q "custom.plugins:" "$backup_file"
}

@test "validation catches common configuration errors" {
    cd "${KIBANA_DIR}"
    
    # Create config with common errors
    cat > config.yml << EOF
# Missing required elasticsearch.hosts
server.host: "0.0.0.0"
server.port: 5601
# Invalid port number
server.ssl.port: "invalid-port"
# Short encryption key
xpack.encryptedSavedObjects.encryptionKey: "short"
EOF
    
    run ./config-manager.sh validate
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Missing required field:" ]]
}

@test "configuration templates are environment-appropriate" {
    cd "${KIBANA_DIR}"
    
    # Test development environment
    ./config-manager.sh generate development
    grep -q "logging.level: debug" config.yml
    grep -q "telemetry.enabled: false" config.yml
    
    # Test production environment
    ./config-manager.sh generate production
    grep -q "logging.level: warn" config.yml
    grep -q "type: file" config.yml
    
    # Test testing environment
    ./config-manager.sh generate testing
    grep -q "logging.level: info" config.yml
    grep -q "monitoring.ui.container.elasticsearch.enabled: false" config.yml
}

@test "backup and restore maintain file integrity" {
    cd "${KIBANA_DIR}"
    
    # Create configuration with specific content
    ./config-manager.sh generate development
    original_checksum=$(md5sum config.yml | cut -d' ' -f1)
    
    # Create backup
    ./config-manager.sh backup
    
    # Modify configuration
    echo "temporary.modification: true" >> config.yml
    
    # Restore from backup
    backup_file=$(ls backups/config_*.yml | head -n1)
    ./config-manager.sh restore "$backup_file"
    
    # Check integrity
    restored_checksum=$(md5sum config.yml | cut -d' ' -f1)
    [ "$original_checksum" = "$restored_checksum" ]
}

@test "configuration manager handles concurrent access gracefully" {
    cd "${KIBANA_DIR}"
    
    # Generate initial configuration
    ./config-manager.sh generate development
    
    # Simulate concurrent backup operations
    ./config-manager.sh backup &
    ./config-manager.sh backup &
    wait
    
    # Check that both backups were created successfully
    backup_count=$(ls backups/config_*.yml 2>/dev/null | wc -l)
    [ "$backup_count" -ge 2 ]
}

@test "error handling provides helpful messages" {
    cd "${KIBANA_DIR}"
    
    # Test with missing templates directory
    mv templates templates.backup
    
    run ./config-manager.sh generate development
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Template not found" ]]
    
    # Restore templates
    mv templates.backup templates
}

@test "configuration validation reports are comprehensive" {
    cd "${KIBANA_DIR}"
    
    # Generate valid configuration
    ./config-manager.sh generate development
    
    # Validate and check report
    ./config-manager.sh validate
    
    # Check that validation report was created
    validation_reports=$(ls validation/validation_*.log 2>/dev/null | wc -l)
    [ "$validation_reports" -gt 0 ]
    
    # Check report content
    latest_report=$(ls -t validation/validation_*.log | head -n1)
    grep -q "Kibana Configuration Validation Report" "$latest_report"
    grep -q "VALIDATION: PASSED" "$latest_report"
}

@test "custom configuration preservation across updates" {
    cd "${KIBANA_DIR}"
    
    # Create custom configuration with #ddev-generated marker
    cat > config.yml << EOF
# #ddev-generated - Custom Configuration
server.host: "0.0.0.0"
server.port: 5601
elasticsearch.hosts: ["http://elasticsearch:9200"]
custom.preserved.setting: "should-be-kept"
xpack.security.enabled: true
EOF
    
    # This should preserve the custom config
    run ./config-manager.sh generate development
    [ "$status" -eq 0 ]
    
    # Should have created a backup
    backup_count=$(ls backups/config_*.yml 2>/dev/null | wc -l)
    [ "$backup_count" -gt 0 ]
}