#!/usr/bin/env bash
#ddev-generated

#######################################
# Delete a file in a sophisticated manner.
# Arguments:
#   File to delete, a path.
# Returns:
#   0 if thing was deleted, non-zero on error.
#######################################
function checkStatus
{
  if [ "$status" == "green" ]; then
      printf "%s is green \n" "$1"
  else
      printf "%s is not green, status is %2\n" "$1" "$status"
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
    setStatusFromAddress "http://elasticsearch:9200/_cluster/health" ".status"
    checkStatus "elastic";

    setStatusFromAddress "http://kibana:5601/api/status" ".status.overall.state"
    checkStatus 'kibana'

    exit 0;
else
    echo "Not found curl and/or jq";
    exit 1;
fi