#!/bin/bash
# Usage: rally-extract-tests.sh --uuid myuuid

scratch=$(mktemp)

function finish {
  rm -rf "$scratch"
}
trap finish EXIT

status=success

pass_thru=()
while [[ $# -gt 0 ]]
do
key="$1"
case $key in
    --status)
        status="$2"
        shift # past argument
        shift # past value
    ;;
   *)
 pass_thru+=("$1")
 shift
   ;;
esac
done
rally verify report --type json --to $scratch "${pass_thru[@]}" >/dev/null 3>&1; cat $scratch | jq -r '.tests | to_entries[] | select(.value.by_verification[].status == "'$status'") | "\(.key)"'
