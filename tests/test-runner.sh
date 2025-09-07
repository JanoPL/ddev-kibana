#!/bin/bash

# Test runner for Configuration Management tests
# Runs all BATS tests related to configuration management

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    local missing=()
    
    for cmd in bats yq jq; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing required commands: ${missing[*]}"
        echo "Please install them before running tests:"
        echo "  brew install bats-core yq jq  # macOS"
        echo "  apt install bats yq jq        # Ubuntu"
        return 1
    fi
}

# Run specific test suite
run_test_suite() {
    local test_file="$1"
    local test_name="$(basename "$test_file" .bats)"
    
    log_info "Running $test_name tests..."
    
    if bats "$test_file"; then
        log_info "$test_name tests passed"
        return 0
    else
        log_error "$test_name tests failed"
        return 1
    fi
}

# Main function
main() {
    cd "$SCRIPT_DIR"
    
    log_info "DDEV Kibana Configuration Management Test Suite"
    log_info "=============================================="
    
    # Check prerequisites
    if ! check_prerequisites; then
        exit 1
    fi
    
    # Set up test environment
    export BATS_TEST_DIRNAME="$SCRIPT_DIR"
    export PROJECT_ROOT="$PROJECT_ROOT"
    
    local failed_tests=0
    local total_tests=0
    
    # Run individual test suites
    for test_file in test-config-*.bats; do
        if [ -f "$test_file" ]; then
            ((total_tests++))
            if ! run_test_suite "$test_file"; then
                ((failed_tests++))
            fi
            echo
        fi
    done
    
    # Summary
    log_info "Test Summary"
    log_info "============"
    log_info "Total test suites: $total_tests"
    log_info "Passed: $((total_tests - failed_tests))"
    
    if [ $failed_tests -gt 0 ]; then
        log_error "Failed: $failed_tests"
        exit 1
    elif [ $total_tests -eq 0 ]; then
        log_warning "Nothing to test"
        exit 0
    else
        log_info "All tests passed!"
        exit 0
    fi
}

# Handle command line arguments
case "${1:-all}" in
    "management")
        run_test_suite "test-config-management.bats"
        ;;
    "integration")
        run_test_suite "test-config-integration.bats"
        ;;
    "all"|*)
        main
        ;;
esac