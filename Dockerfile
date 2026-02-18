FROM node:20.15.1

ARG REACTORY_CONFIG_ID
ARG REACTORY_ENV_ID

ENV BUILD_VERSION=latest
ENV ENV_ID=${REACTORY_ENV_ID:-podman}
ENV CONFIG_ID=${REACTORY_CONFIG_ID:-reactory}
# Define environment variables
ENV CERTIFICATES_PATH=/usr/local/share/ca-certificates
ENV WORKDIR_PATH=/${CONFIG_ID}/reactory-express-server
ENV BUILD_TAR_FILE=${CONFIG_ID}-server-${ENV_ID}-${BUILD_VERSION}.tar.gz

# Copy certificates to the container default certificates path
# Remove this line if you don't need to add custom certificates 
# for VPN or other services
COPY certificates/ ${CERTIFICATES_PATH}/

# Update the trusted certificates store
# Install the necessary packages
RUN update-ca-certificates && \
	apt-get update -y && \
	apt-get -y install \
	build-essential \
	chromium \
	libcairo2-dev \
	libgif-dev \
	libjpeg-dev \
	libpango1.0-dev \
	librsvg2-dev && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

ENV NODE_EXTRA_CA_CERTS=${CERTIFICATES_PATH}/ca-certificates.crt
# check if the certificate we added is in the trusted certificates store
RUN openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt ${CERTIFICATES_PATH}/ca-certificates.crt

WORKDIR /

# Create a reactory user and group
# RUN groupadd -r reactory && useradd -r -g reactory reactory

# Set the password for the reactory user using environment variables
# ENV REACTORY_USER_PASSWORD=${REACTORY_USER_PASSWORD:-reactory}
# RUN echo "reactory:${REACTORY_USER_PASSWORD}" | chpasswd

RUN mkdir -p /reactory/reactory-core && \
	mkdir -p /reactory/reactory-express-server && \
	mkdir -p /reactory/reactory-pwa-client && \
	mkdir -p /reactory/reactory-data && \
	mkdir -p /reactory/reactory-docs && \
	mkdir -p /reactory/reactory-data/plugins

WORKDIR ${WORKDIR_PATH}

COPY build/server/${CONFIG_ID}/${BUILD_TAR_FILE} ${WORKDIR_PATH}

RUN tar -xvzf ${BUILD_TAR_FILE} > /dev/null 2>&1 && \
	rm ${BUILD_TAR_FILE} && \
	yarn install --production && \
	yarn global add env-cmd && \
	yarn cache clean && \
	rm -rf /tmp/*
