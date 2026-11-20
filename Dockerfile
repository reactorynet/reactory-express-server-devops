# NODE_VERSION and BUN_VERSION must be declared before FROM so they can be used in FROM instructions.
# The default matches .nvmrc — override by passing --build-arg NODE_VERSION=<version>.
ARG NODE_VERSION=20.19.4
ARG BUN_VERSION=1.4.2

FROM oven/bun:${BUN_VERSION} AS bun-image
FROM node:${NODE_VERSION}

# Install Bun runtime (default version 1.4.2)
COPY --from=bun-image /usr/local/bin/bun /usr/local/bin/bun
RUN ln -s /usr/local/bin/bun /usr/local/bin/bunx && bun --version

ARG REACTORY_CONFIG_ID
ARG REACTORY_ENV_ID
ARG BUN_VERSION=1.4.2
# Passed by build-image.sh: "true" when *.crt files exist in the local certificates/ dir.
# Controls whether custom cert installation and verification steps are executed.
ARG HAS_CUSTOM_CERTS=false
# When HAS_CUSTOM_CERTS=true, build-image.sh sets this to the in-image cert bundle path
# so that Node.js trusts custom CA certificates at runtime.
ARG NODE_EXTRA_CA_CERTS_VALUE=""

# BUILD_VERSION is passed from build-image.sh (read from package.json).
# Declaring it as an ARG first lets it override the ENV default below.
ARG BUILD_VERSION=latest
ENV BUILD_VERSION=${BUILD_VERSION}
ENV ENV_ID=${REACTORY_ENV_ID:-podman}
ENV CONFIG_ID=${REACTORY_CONFIG_ID:-reactory}
ENV CERTIFICATES_PATH=/usr/local/share/ca-certificates
ENV WORKDIR_PATH=/${CONFIG_ID}/reactory-express-server
ENV BUILD_TAR_FILE=${CONFIG_ID}-server-${ENV_ID}-${BUILD_VERSION}.tar.gz
# Only set when custom certs are present; empty string means Node uses its default trust store.
ENV NODE_EXTRA_CA_CERTS=${NODE_EXTRA_CA_CERTS_VALUE}
ENV BUN_VERSION=${BUN_VERSION}
ENV PYTHON=/usr/bin/python3
ENV SHARP_IGNORE_GLOBAL_LIBVIPS=1

# Playwright resolves its browser from PLAYWRIGHT_BROWSERS_PATH. Pinned to an explicit absolute
# path instead of the default (~/.cache/ms-playwright): the location is operator-visible, it is the
# same for every process regardless of HOME, and it survives a future non-root USER.
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

# Copy certificates into the image.
# build-image.sh guarantees the local certificates/ directory exists (creating it if absent),
# so this COPY is always safe even when no custom certs are provided.
COPY certificates/ ${CERTIFICATES_PATH}/

# update-ca-certificates only picks up files ending in .crt — normalize any
# .pem certs (e.g. a corporate root CA exported as .pem) to .crt first so
# they actually get added to the trust store instead of silently ignored.
RUN for pem in ${CERTIFICATES_PATH}/*.pem; do \
		[ -f "$pem" ] && cp "$pem" "${pem%.pem}.crt"; \
	done; \
	true

# Update the system trust store, then conditionally verify the custom cert bundle.
# The verify step is skipped when HAS_CUSTOM_CERTS is not "true", preventing a build
# failure when no custom certificates are present.
RUN update-ca-certificates && \
	if [ "${HAS_CUSTOM_CERTS}" = "true" ]; then \
		echo "🔐 Verifying custom certificate bundle..." && \
		for cert in ${CERTIFICATES_PATH}/*.crt; do \
			openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt "$cert" || exit 1; \
		done && \
		echo "✅ Custom certificate bundle verified"; \
	else \
		echo "ℹ️  HAS_CUSTOM_CERTS is not set — skipping custom certificate verification"; \
	fi

# Install required system packages.
RUN apt-get update -y && \
	apt-get -y install \
	build-essential \
	pkg-config \
	python3 \
	python-is-python3 \
	chromium \
	libcairo2-dev \
	libgif-dev \
	libjpeg-dev \
	libpango1.0-dev \
	librsvg2-dev \
	libvips-dev && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

WORKDIR /

RUN mkdir -p /reactory/reactory-core && \
	mkdir -p /reactory/reactory-express-server && \
	mkdir -p /reactory/reactory-pwa-client && \
	mkdir -p /reactory/reactory-data && \
	mkdir -p /reactory/reactory-docs && \
	mkdir -p /reactory/reactory-data/plugins

WORKDIR ${WORKDIR_PATH}

COPY build/server/${CONFIG_ID}/${BUILD_TAR_FILE} ${WORKDIR_PATH}

RUN corepack enable && \
	tar -xvzf ${BUILD_TAR_FILE} > /dev/null 2>&1 && \
	rm ${BUILD_TAR_FILE} && \
	if [ -d "${WORKDIR_PATH}/data" ]; then \
		echo "📦 Populating /reactory/reactory-data from build data..." && \
		cp -r ${WORKDIR_PATH}/data/* /reactory/reactory-data/ && \
		chmod -R a+rX /reactory/reactory-data; \
	fi && \
	yarn workspaces focus --all --production && \
	npm install -g env-cmd && \
	yarn cache clean && \
	rm -rf /tmp/*

# ── Playwright browser provisioning ───────────────────────────────────────────────────────────
# The playwright npm package does NOT contain a browser. It pins one build per release and
# `playwright install` downloads it; installing the package alone yields an image that has
# playwright and zero browsers, where every browser macro and ReactorPlaywrightService fails at
# first use:
#
#   browserType.launch: Executable doesn't exist at
#     /root/.cache/ms-playwright/chromium_headless_shell-1217/chrome-headless-shell-linux64/...
#
# CHROMIUM ONLY. This codebase imports `chromium` plus browser types and nothing else — firefox,
# webkit and ffmpeg are never launched, so installing them would only add image size.
# `--with-deps` also installs the chromium system libraries, and the install covers BOTH
# `chromium` and `chromium-headless-shell`, which matters because `headless: true` launches go
# through the headless shell.
#
# It runs AFTER `yarn workspaces focus` so the CLI is the version the lockfile pinned, and
# `${PLAYWRIGHT_BROWSERS_PATH}` is outside WORKDIR so nothing later in this stage can overwrite it.
# GUARDED, because playwright's presence depends on how the image was built.
#
# playwright is declared by the @reactory/reactor WORKSPACE, which only exists when
# bin/install.sh has fetched src/modules and bin/build.sh has copied them to
# app/modules. It is NOT a dependency of the root project. Two build shapes exist:
#
#   with modules   the reactor workspace is present, `yarn workspaces focus`
#                  installs its dependency, node_modules/.bin/playwright exists.
#                  This is the production image and the only one that can launch a
#                  browser.
#
#   core-only      CI's build-smoke-test.yml deliberately builds without the module
#                  repos. app/modules still EXISTS - babel compiles
#                  src/modules/index.ts there - but it holds no workspace: no
#                  directory under it has a package.json. So there is no CLI and
#                  nothing that could launch a browser.
#
# The test is therefore for the REACTOR WORKSPACE, not for a non-empty app/modules.
# The first version of this guard asked "is app/modules non-empty", which is true in
# a core-only build because of the compiled index.js, and so it took the failure
# branch on a build that had nothing to provision.
#
# The distinction matters: a core-only build has nothing to provision and must not
# fail, but a MODULE-BEARING build whose playwright install silently went missing is
# exactly the bug this whole change exists to prevent. So that case fails loudly.
RUN if [ ! -f app/modules/reactory-reactor/package.json ]; then \
		echo "core-only image: no reactory module workspace, so playwright is not installed"; \
		echo "skipping browser provisioning - this image cannot run a browser macro anyway"; \
	elif [ ! -x node_modules/.bin/playwright ]; then \
		echo "FAIL: app/modules/reactory-reactor is present but node_modules/.bin/playwright is missing"; \
		echo "the reactor workspace declares playwright, so the workspace install is broken"; \
		exit 1; \
	else \
		node_modules/.bin/playwright install --with-deps chromium && \
		node_modules/.bin/playwright --version && \
		chmod -R a+rX ${PLAYWRIGHT_BROWSERS_PATH}; \
	fi

# Launch gate: fails the BUILD — not the first browser macro — when the provisioned browser is
# missing or does not match the installed package. Byte-identical to the module repo's
# scripts/verify/playwright-browser-smoke.js; baked into the image so an operator can re-run it:
#   podman run --rm <image> node /usr/local/bin/reactory-playwright-smoke.js
COPY bin/verify/playwright-browser-smoke.js /usr/local/bin/reactory-playwright-smoke.js
# The gate can only run where playwright exists (see the guard above). In a
# core-only image it is baked in for an operator but not executed, because there
# is nothing to launch. It says so rather than passing silently.
RUN if [ -x node_modules/.bin/playwright ]; then \
		node /usr/local/bin/reactory-playwright-smoke.js; \
	else \
		echo "launch gate SKIPPED (not passed): playwright is not installed in this core-only image"; \
	fi
