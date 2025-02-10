FROM node:20.15.1

ENV BUILD_VERSION=1.1.0
ENV ENV_ID=${REACTORY_ENV_ID:-podman}
ENV CONFIG_ID=${REACTORY_CONFIG_ID:-reactory}
# Define environment variables
ENV CERTIFICATES_PATH=/usr/local/share/ca-certificates
ENV WORKDIR_PATH=/${CONFIG_ID}/reactory-express-server
ENV BUILD_TAR_FILE=${CONFIG_ID}-server-${ENV_ID}-${BUILD_VERSION}.tar.gz

# Copy certificates to the container default certificates path
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

# Add networking utilities ping and tracert
RUN apt-get update && apt-get install -y iputils-ping traceroute && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

# Add nano editor
RUN apt-get update && apt-get install -y nano && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

ENV NODE_EXTRA_CA_CERTS=${CERTIFICATES_PATH}/ca-certificates.crt
# check if the certificate we added is in the trusted certificates store
RUN openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt ${CERTIFICATES_PATH}/ca-certificates.crt

WORKDIR /

RUN mkdir -p /reactory/reactory-core && \
	mkdir -p ${WORKDIR_PATH} && \
	mkdir -p /reactory/reactory-pwa-client && \
	mkdir -p /reactory/reactory-data && \
	mkdir -p /reactory/reactory-docs

WORKDIR ${WORKDIR_PATH}

COPY build/server/${CONFIG_ID}/${BUILD_TAR_FILE} ${WORKDIR_PATH}

RUN tar -xvzf ${BUILD_TAR_FILE} > /dev/null 2>&1 && \
	rm ${BUILD_TAR_FILE} && \
	yarn install && \
	yarn global add env-cmd
