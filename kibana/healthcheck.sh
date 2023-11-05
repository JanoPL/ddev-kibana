#!/usr/bin/env bash
#ddev-generated

#######################################
# Check green status 
# Arguments:
#   status name
# Returns:
#   0 if thing was correct status, non-zero on error.
#######################################
function checkGreenStatus
{
    if [ "$status" == "green" ]; then
        printf "%s is green \n" "$1"
    else
        printf "%s is not green, status is %2\n" "$1" "$status"
        exit 1;
    fi
}

#######################################
# Check available status 
# Arguments:
#   status name
# Returns:
#   0 if thing was correct status, non-zero on error.
#######################################
function checkAvailableStatus
{
  if [ "$status" == "available" ]; then
        printf "%s is available \n" "$1"
    else
        printf "%s is not available, status is %2\n" "$1" "$status"
        exit 1;
    fi
}

#######################################
# Set globally status from curl response
# Arguments:
#   address, json dot notation to check status
# Returns:
#   non-zero on error.
#######################################
function setStatusFromAddress
{
  status=$(curl -s --location "$1" --header 'Content-Type: application/json' | jq --raw-output "$2")
}

#######################################
# Main
#######################################
if command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1
  then
    if [[ ${KIBANA_VERSION} -ge 7.0.0 && ${KIBANA_VERSION} -le 8.0.0 ]]
      then
        setStatusFromAddress "http://elasticsearch:9200/_cluster/health" ".status"
        checkGreenStatus "elastic";

        setStatusFromAddress "http://kibana:5601/api/status" ".status.overall.state"
        checkGreenStatus 'kibana'
    fi

    if [[ ${KIBANA_VERSION} -ge 8.0.0 && ${KIBANA_VERSION} -le 9.0.0 ]]
      then
        setStatusFromAddress "http://elasticsearch:9200/_cluster/health" ".status"
        checkGreenStatus "elastic";

        setStatusFromAddress "http://kibana:5601/api/status" ".status.overall.level"
        checkAvailableStatus 'available'
    fi

    exit 0;
else
    echo "Not found curl and/or jq";
    exit 1;
fi