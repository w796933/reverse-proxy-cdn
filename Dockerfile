# @summary     reverse-proxy-cdn
#
# @description 
#
# @author      Bernardo Donadio <bcdonadio@alligo.com.br>
# @author      Emerson Rocha Luiz <emerson@alligo.com.br>
# @copyright   Alligo Tecnologia Ltda 2016. All rights reserved

FROM debian:jessie

ENV NODE_VERSION v6.1.0
ENV CONSUL_VERSION=0.6.4
ENV DOCKER_BASE_VERSION=0.0.4

CMD [ "/bin/dumb-init", "-v", "/bin/sh", "/docker-entrypoint.sh" ]

RUN rm /bin/sh \
    && ln -s /bin/bash /bin/sh \
    && echo America/Sao_Paulo > /etc/timezone \
    && dpkg-reconfigure --frontend noninteractive tzdata \
    && apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y g++ gcc make python git curl ca-certificates sed haproxy gnupg openssl wget unzip --no-install-recommends \
    && rm -rf /tmp/* \
    && apt-get clean

WORKDIR /tmp/consul
RUN addgroup consul \
    && adduser --system --ingroup consul consul \
    && gpg --keyserver pgp.mit.edu --recv-keys 91A6E7F85D05C65630BEF18951852D87348FFC4C \
    && wget https://releases.hashicorp.com/docker-base/${DOCKER_BASE_VERSION}/docker-base_${DOCKER_BASE_VERSION}_linux_amd64.zip \
    && wget https://releases.hashicorp.com/docker-base/${DOCKER_BASE_VERSION}/docker-base_${DOCKER_BASE_VERSION}_SHA256SUMS \
    && wget https://releases.hashicorp.com/docker-base/${DOCKER_BASE_VERSION}/docker-base_${DOCKER_BASE_VERSION}_SHA256SUMS.sig \
    && gpg --batch --verify docker-base_${DOCKER_BASE_VERSION}_SHA256SUMS.sig docker-base_${DOCKER_BASE_VERSION}_SHA256SUMS \
    && grep ${DOCKER_BASE_VERSION}_linux_amd64.zip docker-base_${DOCKER_BASE_VERSION}_SHA256SUMS | sha256sum -c \
    && unzip docker-base_${DOCKER_BASE_VERSION}_linux_amd64.zip \
    && cp bin/gosu bin/dumb-init /bin \
    && wget https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip \
    && wget https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_SHA256SUMS \
    && wget https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_SHA256SUMS.sig \
    && gpg --batch --verify consul_${CONSUL_VERSION}_SHA256SUMS.sig consul_${CONSUL_VERSION}_SHA256SUMS \
    && grep consul_${CONSUL_VERSION}_linux_amd64.zip consul_${CONSUL_VERSION}_SHA256SUMS | sha256sum -c \
    && unzip -d /bin consul_${CONSUL_VERSION}_linux_amd64.zip \
    && mkdir -p /opt/consul/data /opt/consul/consulcfg \
    && chown -R consul:consul /opt/consul \
    && rm -rf /tmp/build /root/.gnupg

WORKDIR /opt/nvm
RUN git clone https://github.com/creationix/nvm.git /opt/nvm \
    && source /opt/nvm/nvm.sh \
    && nvm install $NODE_VERSION \
    && nvm use $NODE_VERSION \
    && nvm alias default $NODE_VERSION \
    && ln -s /opt/nvm/versions/node/$NODE_VERSION/bin/node /usr/bin/node \
    && ln -s /opt/nvm/versions/node/$NODE_VERSION/bin/npm /usr/bin/npm

#Correção para o bug https://github.com/npm/npm/issues/9863
RUN cd $(npm root -g)/npm \
    && npm install fs-extra \
    && sed -i -e s/graceful-fs/fs-extra/ -e s/fs.rename/fs.move/ ./lib/utils/rename.js

WORKDIR /opt/src
COPY src/package.json /opt/src/package.json
RUN npm install -g node-gyp nan

COPY src/ /opt/src/
RUN mv config/config-example.json config/config.json
RUN npm install

#COPY consulcfg/ /opt/consul/consulcfg
COPY run/ /opt/run
COPY docker-entrypoint.sh /docker-entrypoint.sh