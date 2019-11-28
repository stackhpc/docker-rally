FROM ubuntu:18.04

RUN sed -i s/^deb-src.*// /etc/apt/sources.list

RUN apt-get update && apt-get install --yes sudo python python-pip vim git-core crudini jq && \
    pip install --upgrade pip && \
    useradd -u 65500 -m rally && \
    usermod -aG sudo rally && \
    echo "rally ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/00-rally-user

COPY etc/motd /etc/motd
WORKDIR /opt/rundeck
COPY bindep.txt /opt/rundeck/

# ensure that we have all system packages installed
RUN pip install bindep &&  apt-get install --yes $(bindep -b | tr '\n' ' ')

RUN pip install git+https://github.com/openstack/rally-openstack.git  --constraint https://raw.githubusercontent.com/openstack/rally-openstack/master/upper-constraints.txt && \
    pip install pymysql && \
    pip install psycopg2 && \
    mkdir /etc/rally && \
    echo "[database]" > /etc/rally/rally.conf && \
    echo "connection=sqlite:////home/rally/data/rally.db" >> /etc/rally/rally.conf
RUN echo '[ ! -z "$TERM" -a -r /etc/motd ] && cat /etc/motd' >> /etc/bash.bashrc
# Cleanup pip
RUN rm -rf /root/.cache/

# Pre-download tempest to speed up runs
RUN git clone --bare https://opendev.org/openstack/tempest /opt/tempest

USER rally
ENV HOME /home/rally
RUN mkdir -p /home/rally/data && mkdir ~/.rally && cp /etc/rally/rally.conf ~/.rally/ && rally db recreate &&\
    rally verify create-verifier --name default --type tempest

COPY bin/rally-verify-wrapper.sh /usr/bin/rally-verify-wrapper.sh
COPY bin/rally-extract-tests.sh /usr/bin/rally-extract-tests.sh

# Docker volumes have specific behavior that allows this construction to work.
# Data generated during the image creation is copied to volume only when it's
# attached for the first time (volume initialization)
VOLUME ["/home/rally/data"]
ENTRYPOINT ["rally"]
