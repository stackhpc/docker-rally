FROM ubuntu:20.04

RUN sed -i s/^deb-src.*// /etc/apt/sources.list

ARG TEMPEST_SOURCE=https://github.com/openstack/tempest
ARG TEMPEST_VERSION=master

RUN apt-get update && apt-get install --yes sudo python3-dev python3-pip vim git-core crudini jq iputils-ping && \
    apt clean && \
    pip3 --no-cache-dir install --upgrade pip setuptools && \
    useradd -u 65500 -m rally && \
    usermod -aG sudo rally && \
    echo "rally ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/00-rally-user && \
    mkdir /rally && chown -R rally:rally /rally

RUN pip install git+https://github.com/stackhpc/rally-openstack.git@fixtures_fix --no-cache-dir && \
    pip3 install pymysql psycopg2-binary --no-cache-dir

COPY ./etc/motd_for_docker /etc/motd
RUN echo '[ ! -z "$TERM" -a -r /etc/motd ] && cat /etc/motd' >> /etc/bash.bashrc

USER rally
ENV HOME /home/rally
RUN mkdir -p /home/rally/.rally

RUN touch ~/.rally/rally.conf
RUN crudini --set ~/.rally/rally.conf database connection sqlite:////home/rally/.rally/rally.db

RUN rally db recreate

RUN rally verify create-verifier --name default --type tempest --source $TEMPEST_SOURCE --version $TEMPEST_VERSION

COPY bin/rally-verify-wrapper.sh /usr/bin/rally-verify-wrapper.sh
COPY bin/rally-extract-tests.sh /usr/bin/rally-extract-tests.sh

# Data generated during the image creation is copied to volume only when it's
# attached for the first time (volume initialization)
VOLUME ["/home/rally/.rally"]
