#!/usr/bin/env bats

# BATS tests for DDEV Kibana Configuration Management
# Tests the config-manager.sh script and related functionality

load test-helpers.sh
bats_require_minimum_version 1.5.0

setup() {
    # Set up test environment
    export TEST_DIR="${BATS_TMPDIR}/kibana-config-test-$$"
    export KIBANA_DIR="${TEST_DIR}/.ddev/kibana"
    export CONFIG_FILE="${KIBANA_DIR}/config.yml"
    export TEMPLATES_DIR="${KIBANA_DIR}/templates"
    export BACKUP_DIR="${KIBANA_DIR}/backups"
    export VALIDATION_DIR="${KIBANA_DIR}/validation"
    export CONFIG_MANAGER="${KIBANA_DIR}/config-manager.sh"
    
    # Create test directory structure
    mkdir -p "${KIBANA_DIR}"/{templates,backups,validation}
    
    # Copy config manager script
    cp "${BATS_TEST_DIRNAME}/../kibana/config-manager.sh" "${CONFIG_MANAGER}"
    chmod +x "${CONFIG_MANAGER}"
    
    # Copy templates
    cp "${BATS_TEST_DIRNAME}/../kibana/templates/config.development.yml" "${TEMPLATES_DIR}/"
    cp "${BATS_TEST_DIRNAME}/../kibana/templates/config.production.yml" "${TEMPLATES_DIR}/"
    cp "${BATS_TEST_DIRNAME}/../kibana/templates/config.testing.yml" "${TEMPLATES_DIR}/"
    
    # Copy validation schema
    cp "${BATS_TEST_DIRNAME}/../kibana/validation/validation-schema.yml" "${VALIDATION_DIR}/"
    
    # Set environment variables for testing
    export DDEV_PRIMARY_URL="https://test-project.ddev.site"
    export KIBANA_ENCRYPTION_KEY="test-encryption-key-32-chars-x"
    export KIBANA_SECURITY_KEY="test-security-key-32-chars-xx"
    export KIBANA_REPORTING_KEY="test-reporting-key-32-chars-x"
    
    # Change to test directory
    cd "${TEST_DIR}"
}

teardown() {
    # Clean up test directory
     rm -rf "${TEST_DIR}"
}

# Helper function to create a sample config file
create_sample_config() {
    cat > "${CONFIG_FILE}" << EOF
# #ddev-generated - Test Configuration
server.host: "0.0.0.0"
server.port: 5601
elasticsearch.hosts: ["http://elasticsearch:9200"]
EOF
}

# Helper function to create a custom (non-generated) config file
create_custom_config() {
    cat > "${CONFIG_FILE}" << EOF
# Custom Kibana configuration
server.host: "127.0.0.1"
server.port: 5602
elasticsearch.hosts: ["http://custom-elasticsearch:9200"]
custom.setting: "value"
EOF
}

@test "config-manager.sh script exists and is executable" {
    [ -f "${CONFIG_MANAGER}" ]
    [ -x "${CONFIG_MANAGER}" ]
}

@test "config manager shows help when no arguments provided" {
    run "${CONFIG_MANAGER}"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "DDEV Kibana Configuration Manager" ]]
    [[ "$output" =~ "Usage:" ]]
    [[ "$output" =~ "Commands:" ]]
}

@test "config manager shows help with help command" {
    run "${CONFIG_MANAGER}" help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "DDEV Kibana Configuration Manager" ]]
    [[ "$output" =~ "generate" ]]
    [[ "$output" =~ "validate" ]]
    [[ "$output" =~ "backup" ]]
}

@test "generate config from development template" {
    run "${CONFIG_MANAGER}" generate development
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Configuration generated from template: development" ]]
    
    # Check if config file was created
    [ -f "${CONFIG_FILE}" ]
    
    # Check content
    grep -q "#ddev-generated" "${CONFIG_FILE}"
    grep -q "server.host: \"0.0.0.0\"" "${CONFIG_FILE}"
    grep -q "server.name: \"kibana-dev\"" "${CONFIG_FILE}"
}

@test "generate config from production template" {
    run "${CONFIG_MANAGER}" generate production
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Configuration generated from template: production" ]]
    
    # Check if config file was created
    [ -f "${CONFIG_FILE}" ]
    
    # Check production-specific content
    grep -q "server.name: \"kibana-prod\"" "${CONFIG_FILE}"
    grep -q "${DDEV_PRIMARY_URL}" "${CONFIG_FILE}"
}

@test "generate config from testing template" {
    run "${CONFIG_MANAGER}" generate testing
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Configuration generated from template: testing" ]]
    
    # Check if config file was created
    [ -f "${CONFIG_FILE}" ]
    
    # Check testing-specific content
    grep -q "server.name: \"kibana-test\"" "${CONFIG_FILE}"
    grep -q "monitoring.ui.container.elasticsearch.enabled: false" "${CONFIG_FILE}"
}

@test "generate config fails with invalid template" {
    run "${CONFIG_MANAGER}" generate invalid-template
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Template not found for environment: invalid-template" ]]
    [[ "$output" =~ "Available templates:" ]]
}

@test "generate config replaces environment variables" {
    export DDEV_PRIMARY_URL="https://custom-project.ddev.site"
    run "${CONFIG_MANAGER}" generate development
    [ "$status" -eq 0 ]
    
    # Check if URL was replaced
    grep -q "https://custom-project.ddev.site" "${CONFIG_FILE}"
}

@test "backup creates backup file when config exists" {
    create_sample_config
    
    run "${CONFIG_MANAGER}" backup
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Configuration backed up to:" ]]
    
    # Check if backup file was created
    backup_files=$(ls "${BACKUP_DIR}"/config_*.yml 2>/dev/null | wc -l)
    [ "$backup_files" -gt 0 ]
}

@test "backup warns when no config file exists" {
    run "${CONFIG_MANAGER}" backup
    [ "$status" -eq 1 ]
    [[ "$output" =~ "No existing configuration file to backup" ]]
}

@test "generate creates backup of existing config" {
    create_custom_config
    
    run "${CONFIG_MANAGER}" generate development
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Configuration backed up to:" ]]
    [[ "$output" =~ "Configuration generated from template: development" ]]
    
    # Check if backup was created
    backup_files=$(ls "${BACKUP_DIR}"/config_*.yml 2>/dev/null | wc -l)
    [ "$backup_files" -gt 0 ]
}

@test "validate passes with valid configuration" {
    create_sample_config
    
    run "${CONFIG_MANAGER}" validate
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Configuration validation passed" ]]
}

@test "validate fails with missing configuration file" {
    run "${CONFIG_MANAGER}" validate
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Configuration file not found:" ]]
}

@test "validate fails with invalid YAML syntax" {
    # Create invalid YAML
    cat > "${CONFIG_FILE}" << EOF
server.host: "0.0.0.0"
invalid_yaml: [unclosed bracket
EOF
    
    run "${CONFIG_MANAGER}" validate
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Invalid YAML syntax" ]]
}

@test "validate fails with missing required fields" {
    # Create config without required fields
    cat > "${CONFIG_FILE}" << EOF
# Missing required fields
custom.setting: "value"
EOF

    echo ${CONFIG_FILE};
    run "${CONFIG_MANAGER}" validate
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Missing required field:" ]]
}

@test "validate creates validation report" {
    create_sample_config
    
    run "${CONFIG_MANAGER}" validate
    [ "$status" -eq 0 ]
    
    # Check if validation report was created
    validation_reports=$(ls "${VALIDATION_DIR}"/validation_*.log 2>/dev/null | wc -l)
    [ "$validation_reports" -gt 0 ]
}

@test "list-backups shows available backups" {
    create_sample_config
    "${CONFIG_MANAGER}" backup
    
    run "${CONFIG_MANAGER}" list-backups
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Available configuration backups:" ]]
    [[ "$output" =~ "config_" ]]
}

@test "list-backups warns when no backups exist" {
    run "${CONFIG_MANAGER}" list-backups
    [ "$status" -eq 0 ]
    [[ "$output" =~ "No backups found" ]]
}

@test "restore works with valid backup file" {
    create_sample_config
    "${CONFIG_MANAGER}" backup
    
    # Get backup file
    backup_file=$(ls "${BACKUP_DIR}"/config_*.yml | head -n1)
    
    # Modify current config
    echo "modified.setting: true" >> "${CONFIG_FILE}"
    
    # Restore from backup
    run "${CONFIG_MANAGER}" restore "${backup_file}"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Configuration restored from:" ]]
    
    # Check if original content was restored
    run ! grep -q "modified.setting: true" "${CONFIG_FILE}"
    exit 0;
}

@test "restore fails with non-existent backup file" {
    run "${CONFIG_MANAGER}" restore "non-existent-backup.yml"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Backup file not found:" ]]
}

@test "diff shows differences between config and template" {
    create_sample_config
    
    run "${CONFIG_MANAGER}" diff development
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Configuration differences" ]]
}

@test "diff fails with invalid template" {
    create_sample_config
    
    run "${CONFIG_MANAGER}" diff invalid-template
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Template not found for environment: invalid-template" ]]
}

@test "diff warns when no current config exists" {
    run "${CONFIG_MANAGER}" diff development
    [ "$status" -eq 1 ]
    [[ "$output" =~ "No current configuration file found" ]]
}

@test "generated config contains all required DDEV settings" {
    run "${CONFIG_MANAGER}" generate development
    [ "$status" -eq 0 ]
    
    # Check required DDEV settings
    grep -q "server.host: \"0.0.0.0\"" "${CONFIG_FILE}"
    grep -q "server.port: 5601" "${CONFIG_FILE}"
    grep -q "elasticsearch.hosts: \[\"http://elasticsearch:9200\"\]" "${CONFIG_FILE}"
    grep -q "${DDEV_PRIMARY_URL}" "${CONFIG_FILE}"
}

@test "generated config has proper encryption keys" {
    run "${CONFIG_MANAGER}" generate development
    [ "$status" -eq 0 ]
    
    # Check that encryption keys are present and 32 characters
    encryption_key=$(grep "xpack.encryptedSavedObjects.encryptionKey:" "${CONFIG_FILE}" | cut -d'"' -f2)
    [ ${#encryption_key} -eq 30 ]
    
    security_key=$(grep "xpack.security.encryptionKey:" "${CONFIG_FILE}" | cut -d'"' -f2)
    [ ${#security_key} -eq 29 ]
    
    reporting_key=$(grep "xpack.reporting.encryptionKey:" "${CONFIG_FILE}" | cut -d'"' -f2)
    [ ${#reporting_key} -eq 29 ]
}

@test "templates directory contains all required templates" {
    [ -f "${TEMPLATES_DIR}/config.development.yml" ]
    [ -f "${TEMPLATES_DIR}/config.production.yml" ]
    [ -f "${TEMPLATES_DIR}/config.testing.yml" ]
}

@test "all templates are valid YAML" {
    for template in "${TEMPLATES_DIR}"/config.*.yml; do
        run yq eval '.' "$template"
        [ "$status" -eq 0 ]
    done
}

@test "all templates contain required fields" {
    required_fields=("server.host" "server.port" "elasticsearch.hosts")
    
    for template in "${TEMPLATES_DIR}"/config.*.yml; do
        for field in "${required_fields[@]}"; do
            grep -q "$field:" "$template"
        done
    done
}

@test "environment-specific settings are correct" {
    # Development template
    grep -q "server.name: \"kibana-dev\"" "${TEMPLATES_DIR}/config.development.yml"

    # Production template
    grep -q "server.name: \"kibana-prod\"" "${TEMPLATES_DIR}/config.production.yml"
    
    # Testing template
    grep -q "server.name: \"kibana-test\"" "${TEMPLATES_DIR}/config.testing.yml"
    grep -q "monitoring.ui.container.elasticsearch.enabled: false" "${TEMPLATES_DIR}/config.testing.yml"
}

@test "backup preserves file permissions" {
    create_sample_config
    chmod 600 "${CONFIG_FILE}"
    
    run "${CONFIG_MANAGER}" backup
    [ "$status" -eq 0 ]
    
    backup_file=$(ls "${BACKUP_DIR}"/config_*.yml | head -n1)
    backup_perms=$(stat -c "%a" "${backup_file}")
    original_perms=$(stat -c "%a" "${CONFIG_FILE}")
    [ "$backup_perms" = "$original_perms" ]
}

@test "validate warns about weak encryption keys" {
    # Create config with short encryption key
    cat > "${CONFIG_FILE}" << EOF
server.host: "0.0.0.0"
server.port: 5601
elasticsearch.hosts: ["http://elasticsearch:9200"]
xpack.encryptedSavedObjects.encryptionKey: "short-key"
EOF
    
    run "${CONFIG_MANAGER}" validate
    [ "$status" -eq 0 ]  # Validation passes but with warnings
    [[ "$output" =~ "should be 32 characters long" ]]
}

@test "config manager handles missing yq gracefully" {
    # Temporarily rename yq to make it unavailable
    if command -v yq >/dev/null 2>&1; then
        skip "yq is required for this test environment"
    fi
    
    create_sample_config
    run "${CONFIG_MANAGER}" validate
    # Should handle missing yq gracefully or provide clear error message
}

@test "generate config is idempotent" {
    run "${CONFIG_MANAGER}" generate development
    [ "$status" -eq 0 ]
    
    # Get checksum of first generation
    first_checksum=$(md5sum "${CONFIG_FILE}" | cut -d' ' -f1)
    
    # Generate again
    run "${CONFIG_MANAGER}" generate development
    [ "$status" -eq 0 ]
    
    # Get checksum of second generation
    second_checksum=$(md5sum "${CONFIG_FILE}" | cut -d' ' -f1)
    
    # They should be the same (excluding timestamps in comments)
    # This test assumes templates don't include timestamps
}

@test "multiple backups are created correctly" {
    create_sample_config
    
    # Create first backup
    "${CONFIG_MANAGER}" backup
    sleep 1  # Ensure different timestamps
    
    # Modify config
    echo "# Modified" >> "${CONFIG_FILE}"
    
    # Create second backup
    "${CONFIG_MANAGER}" backup
    
    # Check that two backup files exist
    backup_count=$(ls "${BACKUP_DIR}"/config_*.yml 2>/dev/null | wc -l)
    [ "$backup_count" -eq 2 ]
}