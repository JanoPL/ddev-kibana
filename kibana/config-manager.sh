#!/bin/bash
#ddev-generated

# DDEV Kibana Configuration Manager
# Manages Kibana configuration templates, validation, and backups

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.yml"
TEMPLATES_DIR="${SCRIPT_DIR}/templates"
BACKUP_DIR="${SCRIPT_DIR}/backups"
VALIDATION_DIR="${SCRIPT_DIR}/validation"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create necessary directories
init_directories() {
    mkdir -p "$BACKUP_DIR" "$VALIDATION_DIR"
}

# Backup current configuration
backup_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        local timestamp=$(date +"%Y%m%d_%H%M%S")
        local backup_file="${BACKUP_DIR}/config_${timestamp}.yml"

        # Ensure backup directory exists
        mkdir -p "$BACKUP_DIR"

        # Validate source file is valid YAML before backing up
        if ! yq eval '.' "$CONFIG_FILE" >/dev/null 2>&1; then
            log_warning "Source configuration contains invalid YAML, backing up anyway"
        fi

        # Copy with preserved permissions and verify
        if cp "$CONFIG_FILE" "$backup_file" && [[ -f "$backup_file" ]]; then
            # Double-check the backup is readable
            if [[ -r "$backup_file" ]]; then
                log_success "Configuration backed up to: $backup_file"
                echo "$backup_file"  # Return backup file path
                return 0
            else
                log_error "Backup file created but not readable: $backup_file"
                return 1
            fi
        else
            log_error "Failed to create backup"
            return 1
        fi
    else
        log_warning "No existing configuration file to backup"
        return 1
    fi
}


# Restore configuration from backup
restore_config() {
    local backup_file="$1"

    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi

    # Verify backup file is valid YAML
    if ! yq eval '.' "$backup_file" >/dev/null 2>&1; then
        log_error "Backup file contains invalid YAML: $backup_file"
        return 1
    fi

    # Create a backup of current config before restore (if it exists)
    if [[ -f "$CONFIG_FILE" ]]; then
        backup_config || log_warning "Could not backup current config before restore"
    fi

    # Restore from backup
    cp "$backup_file" "$CONFIG_FILE"

    # Verify restore was successful
    if cp "$backup_file" "$CONFIG_FILE" && [[ -f "$CONFIG_FILE" ]]; then
        # Verify the content was actually copied by comparing checksums
        if [[ $(md5sum "$CONFIG_FILE" | cut -d' ' -f1) == $(md5sum "$backup_file" | cut -d' ' -f1) ]]; then
            log_success "Configuration restored from: $backup_file"
            return 0
        else
            log_error "Configuration file exists but content verification failed"
            return 1
        fi
    else
        log_error "Failed to restore configuration from: $backup_file"
        return 1
    fi

}

# List available backups
list_backups() {
    log_info "Available configuration backups:"
    if [[ -d "$BACKUP_DIR" ]] && [[ -n "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]]; then
        ls -la "$BACKUP_DIR"/*.yml 2>/dev/null | while read -r line; do
            echo "  $line"
        done
    else
        log_warning "No backups found"
    fi
}

# Generate configuration from template
generate_config() {
    local environment="${1:-development}"
    local template_file="${TEMPLATES_DIR}/config.${environment}.yml"

    if [[ ! -f "$template_file" ]]; then
        log_error "Template not found for environment: $environment"
        log_info "Available templates:"
        ls "${TEMPLATES_DIR}"/config.*.yml 2>/dev/null | sed 's/.*config\.\(.*\)\.yml/  \1/' || log_warning "No templates found"
        return 1
    fi

    # Backup existing config
    backup_config || true

    # Replace environment variables in template
    local ddev_url="${DDEV_PRIMARY_URL:-http://localhost}"
    local kibana_encryption_key="${KIBANA_ENCRYPTION_KEY:-$(generate_encryption_key)}"
    local kibana_security_key="${KIBANA_SECURITY_KEY:-$(generate_encryption_key)}"
    local kibana_reporting_key="${KIBANA_REPORTING_KEY:-$(generate_encryption_key)}"

    sed -e "s|\${DDEV_PRIMARY_URL}|${ddev_url}|g" \
        -e "s|\${KIBANA_ENCRYPTION_KEY}|${kibana_encryption_key}|g" \
        -e "s|\${KIBANA_SECURITY_KEY}|${kibana_security_key}|g" \
        -e "s|\${KIBANA_REPORTING_KEY}|${kibana_reporting_key}|g" \
        "$template_file" > "$CONFIG_FILE"

    log_success "Configuration generated from template: $environment"
}

# Generate secure encryption key
generate_encryption_key() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
}

# Validate configuration file
validate_config() {
    local config_file="${1:-$CONFIG_FILE}"
    local validation_report="${VALIDATION_DIR}/validation_$(date +"%Y%m%d_%H%M%S").log"

    log_info "Validating configuration: $config_file"

    # Check if file exists
    if [[ ! -f "$config_file" ]]; then
        log_error "Configuration file not found: $config_file"
        return 1
    fi

    local errors=0

    # Validate YAML syntax
    if ! yq eval '.' "$config_file" >/dev/null 2>&1; then
        log_error "Invalid YAML syntax in configuration file"
        ((errors++))
    fi

    # Validate required fields
    local required_fields=(
        "server.host"
        "server.port"
        "elasticsearch.hosts"
    )

    for field in "${required_fields[@]}"; do
        if [[ $(yq eval "has(\"${field}\")" "$config_file" 2>/dev/null) != "true" ]]; then
            log_error "Missing required field: $field"
            ((errors++))
        fi
    done

    # Check encryption keys length (should be 32 characters)
    local encryption_fields=(
        "xpack.encryptedSavedObjects.encryptionKey"
        "xpack.security.encryptionKey"
        "xpack.reporting.encryptionKey"
    )

    for field in "${encryption_fields[@]}"; do
        local key_value
        key_value=$(yq eval ".\"${field}\"" "$config_file" 2>/dev/null)
        if [[ "$key_value" != "null" ]] && [[ ${#key_value} -ne 32 ]]; then
            log_warning "Encryption key for $field should be 32 characters long (current: ${#key_value})"
        fi
    done

    # Generate validation report
    {
        echo "Kibana Configuration Validation Report"
        echo "Generated: $(date)"
        echo "Configuration file: $config_file"
        echo "Errors found: $errors"
        echo ""
    } > "$validation_report"

    if [[ $errors -eq 0 ]]; then
        log_success "Configuration validation passed"
        echo "VALIDATION: PASSED" >> "$validation_report"
        return 0
    else
        log_error "Configuration validation failed with $errors errors"
        echo "VALIDATION: FAILED ($errors errors)" >> "$validation_report"
        return 1
    fi
}

# Show configuration diff between current and template
show_config_diff() {
    local environment="${1:-development}"
    local template_file="${TEMPLATES_DIR}/config.${environment}.yml"

    if [[ ! -f "$template_file" ]]; then
        log_error "Template not found for environment: $environment"
        return 1
    fi

    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_warning "No current configuration file found"
        return 1
    fi

    log_info "Configuration differences (current vs $environment template):"
    diff -u "$CONFIG_FILE" "$template_file" || true
}

# Interactive configuration wizard
config_wizard() {
    log_info "Starting Kibana Configuration Wizard"

    echo "Available environments:"
    ls "${TEMPLATES_DIR}"/config.*.yml 2>/dev/null | sed 's/.*config\.\(.*\)\.yml/  \1/' || {
        log_error "No templates found"
        return 1
    }

    read -p "Select environment (development/production/testing): " environment
    environment=${environment:-development}

    read -p "Generate new encryption keys? (y/N): " generate_keys
    generate_keys=${generate_keys:-n}

    if [[ "$generate_keys" =~ ^[Yy]$ ]]; then
        export KIBANA_ENCRYPTION_KEY=$(generate_encryption_key)
        export KIBANA_SECURITY_KEY=$(generate_encryption_key)
        export KIBANA_REPORTING_KEY=$(generate_encryption_key)
        log_info "Generated new encryption keys"
    fi

    generate_config "$environment"

    read -p "Validate configuration? (Y/n): " validate
    validate=${validate:-y}

    if [[ "$validate" =~ ^[Yy]$ ]]; then
        validate_config
    fi
}

# Main function
main() {
    init_directories

    case "${1:-help}" in
        "generate")
            generate_config "${2:-development}"
            ;;
        "validate")
            validate_config "${2:-$CONFIG_FILE}"
            ;;
        "backup")
            backup_config
            ;;
        "restore")
            if [[ -z "${2:-}" ]]; then
                list_backups
                read -p "Enter backup file path: " backup_file
            else
                backup_file="$2"
            fi
            restore_config "$backup_file"
            ;;
        "list-backups")
            list_backups
            ;;
        "diff")
            show_config_diff "${2:-development}"
            ;;
        "wizard")
            config_wizard
            ;;
        "help"|*)
            cat << EOF
DDEV Kibana Configuration Manager

Usage: $0 <command> [options]

Commands:
    generate <environment>    Generate configuration from template
                             (environments: development, production, testing)
    validate [config_file]   Validate configuration file
    backup                   Backup current configuration
    restore [backup_file]    Restore configuration from backup
    list-backups            List available configuration backups
    diff <environment>       Show differences between current config and template
    wizard                   Interactive configuration wizard
    help                     Show this help message

Examples:
    $0 generate production
    $0 validate
    $0 backup
    $0 restore backups/config_20240101_120000.yml
    $0 wizard

EOF
            ;;
    esac
}

# Run main function with all arguments
main "$@"