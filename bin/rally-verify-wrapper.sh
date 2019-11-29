#!/bin/bash

# This script assumes the following bind mounts
# - An openrc file bind mounted to /home/rally/openrc
# - A directory mount at /home/rally/artifacts
# - (optional) a skip list mounted at /home/rally/tempest-skip-list
# - (optional) a load list mounted at /home/rally/tempest-load-list
# - (optional) a set of tempest overrides mounts at /home/rally/tempest-overrides.conf

set -eux

artifacts_dir=/home/rally/artifacts
tempest_source_default="--source /opt/tempest"

tempest_source="$tempest_source_default"
if [ ! -z ${TEMPEST_SOURCE+x} ]; then
    tempest_source="--source $TEMPEST_SOURCE"
fi

tempest_version=""
if [ ! -z ${TEMPEST_VERSION+x} ]; then
    tempest_version="--version $TEMPEST_VERSION"
fi

load_list=""
# You can't have a load list and a pattern, pattern takes priority
if [ -f ~/tempest-load-list ] && [ -z ${TEMPEST_PATTERN:+x} ]; then
    load_list="--load-list ~/tempest-load-list"
fi

skip_list=""
if [ -f ~/tempest-skip-list ]; then
    skip_list="--skip-list ~/tempest-skip-list"
fi

pattern=""
if [ ! -z ${TEMPEST_PATTERN-x} ]; then
   pattern="--pattern $TEMPEST_PATTERN"
fi

if [ ! -d $artifacts_dir ]; then
    >&2 echo "You must mount a directory at $artifacts_dir"
    exit -1
fi

# Don't print secrets
set +x
. ~/openrc
set -x

unset OS_CACERT

crudini --set ~/.rally/rally.conf DEFAULT openstack_client_http_timeout 300

rally deployment create --fromenv --name openstack

if [ "$tempest_source" != "$tempest_source_default" ] || [ "$tempest_version" != "" ]; then
    rally verify create-verifier --name tempest --type tempest $tempest_source $tempest_version
fi

if [ -f ~/tempest-overrides.conf ]; then
    rally verify configure-verifier --reconfigure --extend ~/tempest-overrides.conf
fi

rally verify start $skip_list $load_list $pattern \
      > >(tee -a $artifacts_dir/stdout.log) 2> >(tee -a $artifacts_dir/stderr.log >&2)

rally verify report --type html --to $artifacts_dir/rally-verify-report.html
rally verify report --type json --to $artifacts_dir/rally-verify-report.json
rally verify report --type junit-xml --to $artifacts_dir/rally-junit.xml

rally-extract-tests.sh --status fail > $artifacts_dir/failed-tests
