FROM ubuntu:22.04

RUN sed -i s/^deb-src.*// /etc/apt/sources.list

ARG TEMPEST_SOURCE=https://github.com/openstack/tempest
ARG TEMPEST_VERSION=master

ARG TEMPEST_PLUGIN_OCTAVIA_SOURCE=https://github.com/stackhpc/octavia-tempest-plugin
ARG TEMPEST_PLUGIN_OCTAVIA_VERSION=feature/non-admin

ARG TEMPEST_PLUGIN_DESIGNATE_SOURCE=https://github.com/openstack/designate-tempest-plugin
ARG TEMPEST_PLUGIN_DESIGNATE_VERSION=master

ARG TEMPEST_PLUGIN_IRONIC_SOURCE=https://github.com/openstack/ironic-tempest-plugin
ARG TEMPEST_PLUGIN_IRONIC_VERSION=master

ARG TEMPEST_PLUGIN_MANILA_SOURCE=https://github.com/openstack/manila-tempest-plugin
ARG TEMPEST_PLUGIN_MANILA_VERSION=master

ARG TEMPEST_PLUGIN_MAGNUM_SOURCE=https://github.com/openstack/magnum-tempest-plugin
ARG TEMPEST_PLUGIN_MAGNUM_VERSION=master

ARG TEMPEST_PLUGIN_BARBICAN_SOURCE=https://github.com/openstack/barbican-tempest-plugin
ARG TEMPEST_PLUGIN_BARBICAN_VERSION=master

ARG TEMPEST_PLUGIN_CINDER_SOURCE=https://github.com/openstack/cinder-tempest-plugin
ARG TEMPEST_PLUGIN_CINDER_VERSION=master

ARG TEMPEST_PLUGIN_CLOUDKITTY_SOURCE=https://github.com/openstack/cloudkitty-tempest-plugin
ARG TEMPEST_PLUGIN_CLOUDKITTY_VERSION=master

ARG TEMPEST_PLUGIN_GLANCE_SOURCE=https://github.com/openstack/glance-tempest-plugin
ARG TEMPEST_PLUGIN_GLANCE_VERSION=master

ARG TEMPEST_PLUGIN_KEYSTONE_SOURCE=https://github.com/openstack/keystone-tempest-plugin
ARG TEMPEST_PLUGIN_KEYSTONE_VERSION=master

ARG TEMPEST_PLUGIN_NEUTRON_SOURCE=https://github.com/openstack/neutron-tempest-plugin
ARG TEMPEST_PLUGIN_NEUTRON_VERSION=master

# Does not work if included.
# Error output: 'Could not load 'ngs_tests': No module named 'tempest_plugin'
# ARG TEMPEST_PLUGIN_NETWORKING_GENERIC_SWITCH_SOURCE=https://github.com/openstack/networking-generic-switch
# ARG TEMPEST_PLUGIN_NETWORKING_GENERIC_SWITCH_VERSION=master

ARG RALLY_OPENSTACK_SOURCE=https://github.com/stackhpc/rally-openstack.git
# Update after https://github.com/stackhpc/rally-openstack/pull/3/files has been merged.
ARG RALLY_OPENSTACK_VERSION=non-admin-credentials
ARG RALLY_OPENSTACK_UPPER_CONSTRAINTS=https://raw.githubusercontent.com/stackhpc/rally-openstack/$RALLY_OPENSTACK_VERSION/upper-constraints.txt

RUN apt-get update && apt-get install --yes sudo python3-dev python3-pip vim git-core crudini jq iputils-ping && \
    apt clean && \
    pip3 --no-cache-dir install --upgrade pip setuptools && \
    useradd -u 65500 -m rally && \
    usermod -aG sudo rally && \
    echo "rally ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/00-rally-user && \
    mkdir /rally && chown -R rally:rally /rally

RUN pip3 install git+$RALLY_OPENSTACK_SOURCE@$RALLY_OPENSTACK_VERSION pymysql psycopg2-binary fixtures --no-cache-dir -c $RALLY_OPENSTACK_UPPER_CONSTRAINTS

COPY ./etc/motd_for_docker /etc/motd
RUN echo '[ ! -z "$TERM" -a -r /etc/motd ] && cat /etc/motd' >> /etc/bash.bashrc

USER rally
ENV HOME=/home/rally
RUN mkdir -p /home/rally/.rally

RUN touch ~/.rally/rally.conf
RUN crudini --set ~/.rally/rally.conf database connection sqlite:////home/rally/.rally/rally.db

RUN rally db recreate

RUN rally verify create-verifier --name default --type tempest --source $TEMPEST_SOURCE --version $TEMPEST_VERSION

# For simplicitiy, always install common extensions
RUN rally verify add-verifier-ext --source $TEMPEST_PLUGIN_OCTAVIA_SOURCE --version $TEMPEST_PLUGIN_OCTAVIA_VERSION
RUN rally verify add-verifier-ext --source $TEMPEST_PLUGIN_DESIGNATE_SOURCE --version $TEMPEST_PLUGIN_DESIGNATE_VERSION
RUN rally verify add-verifier-ext --source $TEMPEST_PLUGIN_IRONIC_SOURCE --version $TEMPEST_PLUGIN_IRONIC_VERSION
RUN rally verify add-verifier-ext --source $TEMPEST_PLUGIN_MANILA_SOURCE --version $TEMPEST_PLUGIN_MANILA_VERSION
RUN rally verify add-verifier-ext --source $TEMPEST_PLUGIN_MAGNUM_SOURCE --version $TEMPEST_PLUGIN_MAGNUM_VERSION
RUN rally verify add-verifier-ext --source $TEMPEST_PLUGIN_BARBICAN_SOURCE --version $TEMPEST_PLUGIN_BARBICAN_VERSION
RUN rally verify add-verifier-ext --source $TEMPEST_PLUGIN_CINDER_SOURCE --version $TEMPEST_PLUGIN_CINDER_VERSION
RUN rally verify add-verifier-ext --source $TEMPEST_PLUGIN_CLOUDKITTY_SOURCE --version $TEMPEST_PLUGIN_CLOUDKITTY_VERSION
RUN rally verify add-verifier-ext --source $TEMPEST_PLUGIN_GLANCE_SOURCE --version $TEMPEST_PLUGIN_GLANCE_VERSION
RUN rally verify add-verifier-ext --source $TEMPEST_PLUGIN_KEYSTONE_SOURCE --version $TEMPEST_PLUGIN_KEYSTONE_VERSION
RUN rally verify add-verifier-ext --source $TEMPEST_PLUGIN_NEUTRON_SOURCE --version $TEMPEST_PLUGIN_NEUTRON_VERSION
# RUN rally verify add-verifier-ext --source $TEMPEST_PLUGIN_NETWORKING_GENERIC_SWITCH_SOURCE --version $TEMPEST_PLUGIN_NETWORKING_GENERIC_SWITCH_VERSION

COPY bin/rally-verify-wrapper.sh /usr/bin/rally-verify-wrapper.sh
COPY bin/rally-extract-tests.sh /usr/bin/rally-extract-tests.sh
COPY bin/rally-normalize.py /usr/bin/rally-normalize.py
COPY bin/test_server.bin /opt/octavia-tempest-plugin/test_server.bin

# Data generated during the image creation is copied to volume only when it's
# attached for the first time (volume initialization)
VOLUME ["/home/rally/.rally"]
