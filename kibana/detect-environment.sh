#!/bin/bash
#ddev-generated

# Detect appropriate Kibana environment based on DDEV context
# Returns: development, production, or testing

# Default environment
ENVIRONMENT="development"

# Check for production indicators
if [[ "${DDEV_PROJECT_TYPE:-}" == "production" ]] || 
   [[ "${DDEV_KIBANA_ENV:-}" == "production" ]] ||
   [[ "${ENVIRONMENT:-}" == "production" ]]; then
    ENVIRONMENT="production"
# Check for testing indicators
elif [[ "${DDEV_PROJECT_TYPE:-}" == "testing" ]] || 
     [[ "${DDEV_KIBANA_ENV:-}" == "testing" ]] ||
     [[ "${CI:-}" == "true" ]] ||
     [[ "${ENVIRONMENT:-}" == "testing" ]]; then
    ENVIRONMENT="testing"
fi

echo "$ENVIRONMENT"