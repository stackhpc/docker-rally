#!/bin/bash

# This script assumes the following bind mounts
# - An openrc file bind mounted to /home/rally/openrc
# - A directory mount at /home/rally/artifacts
# - (optional) a skip list mounted at /home/rally/tempest-skip-list
# - (optional) a load list mounted at /home/rally/tempest-load-list
# - (optional) a set of tempest overrides mounts at /home/rally/tempest-overrides.conf

set -eux

artifacts_dir=/home/rally/artifacts

load_list=""
# You can't have a load list and a pattern, pattern takes priority
if [ -f ~/tempest-load-list ] && [ -z ${TEMPEST_PATTERN:+x} ]; then
    load_list="--load-list /home/rally/tempest-load-list"
fi

skip_list=""
if [ -f ~/tempest-skip-list ]; then
    skip_list="--skip-list /home/rally/tempest-skip-list"
fi

pattern=""
if [ ! -z ${TEMPEST_PATTERN:+x} ]; then
    pattern="--pattern $TEMPEST_PATTERN"
fi

concurrency=""
if [ ! -z ${TEMPEST_CONCURRENCY:+x} ]; then
    concurrency="--concurrency $TEMPEST_CONCURRENCY"
fi

if [ ! -d $artifacts_dir ]; then
    echo >&2 "You must mount a directory at $artifacts_dir"
    exit -1
fi

# Don't print secrets
set +x
if [ -f ~/openrc ]; then
    . ~/openrc
elif [ ! -z ${TEMPEST_OPENRC:+x} ]; then
    . <(echo "$TEMPEST_OPENRC")
else
    echo >&2 "Could not find openrc file. Please define TEMPEST_OPENRC or copy the file to ~/openrc."
    exit -1
fi
set -x

unset OS_CACERT

crudini --set ~/.rally/rally.conf DEFAULT openstack_client_http_timeout 300
crudini --set ~/.rally/rally.conf openstack flavor_ref_ram 128
crudini --set ~/.rally/rally.conf openstack flavor_ref_alt_ram 256
crudini --set ~/.rally/rally.conf openstack flavor_ref_disk 1
crudini --set ~/.rally/rally.conf openstack flavor_ref_alt_disk 1
crudini --set ~/.rally/rally.conf openstack img_url http://download.cirros-cloud.net/0.5.1/cirros-0.5.1-x86_64-disk.img

rally deployment create --fromenv --name openstack

if [ -f ~/tempest-overrides.conf ]; then
    rally verify configure-verifier --reconfigure --extend ~/tempest-overrides.conf
fi

failed=0
rally verify start $skip_list $load_list $pattern $concurrency > >(tee -a $artifacts_dir/stdout.log) 2> >(tee -a $artifacts_dir/stderr.log >&2) || export failed=1

rally verify report --type html --to $artifacts_dir/rally-verify-report.html
rally verify report --type json --to $artifacts_dir/rally-verify-report.json
rally verify report --type junit-xml --to $artifacts_dir/rally-junit.xml

rally-extract-tests.sh --status fail >$artifacts_dir/failed-tests

# NOTE: this assumes only one of these files exists which should ordinarily
# be the case when the container is discarded after one run.
find ~/.rally -name "tempest.log" -print -exec cp {} $artifacts_dir/ \;

if [ $failed == 1 ]; then
   exit -1
fi
