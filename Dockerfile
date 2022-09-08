# This is the hyperglass user home directory, this is the base dir for configs, static files and python binaries
ARG HYPERGLASS_HOME=/opt

# hyperglass 1.0.4 only supports node 14. See: https://github.com/thatmattlove/hyperglass/issues/209
FROM node:14-bullseye-slim AS base
ARG HYPERGLASS_HOME

# install dependencies (python3 pip zlib libjpeg wget)
# also install some prebuilt python dependencies
RUN \
  apt-get update && \
  apt-get install wget zlib1g libjpeg62-turbo python3 python3-pip python3-aiofiles python3-click python3-distro python3-fastapi python3-gunicorn python3-paramiko python3-psutil python3-redis python3-uvloop python3-xmltodict -y --no-install-recommends && \
  rm -rf /var/lib/apt/lists/*

# Create user hyperglass and chown its home directory
RUN \
  adduser --disabled-password --gecos "" --shell /usr/sbin/nologin --home ${HYPERGLASS_HOME} hyperglass --uid 4001 && \
  chown hyperglass:hyperglass ${HYPERGLASS_HOME}


FROM base AS builder
ARG HYPERGLASS_HOME

# Install build dependencies
RUN apt-get update && apt-get install -y build-essential libssl-dev zlib1g-dev libjpeg-dev git python3-dev

# Download git source
RUN npx degit thatmattlove/hyperglass /hyperglass-src

# Build wheel with world writable cache
WORKDIR /hyperglass-src
# Create cache dir
RUN mkdir -p /tmp/cache && chmod -R 777 /tmp/cache
RUN pip wheel --cache-dir /tmp/cache/ .

# switch user to have a clean home dir
USER hyperglass
# Install the wheel built in the previous step, use the same cache to avoid downloading/building dependencies
# We use --user because hyperglass needs a writable python lib folder
RUN pip install --user --cache-dir /tmp/cache/ --no-warn-script-location hyperglass*.whl

# Initialize node modules (we don't use build-ui because it requires configuration)
# This is the same command used by build-ui: https://github.com/thatmattlove/hyperglass/blob/c52a6f609843177671d38bcad59b8bd658f46b64/hyperglass/util/frontend.py#L96
WORKDIR ${HYPERGLASS_HOME}/.local/lib/python3.9/site-packages/hyperglass/ui
RUN ["/bin/bash", "-c", "yarn --silent --emoji false 2> >(grep -v warning 1>&2)"]

FROM base AS app
USER hyperglass

# Add .local/bin to PATH
ENV PATH="${PATH}:${HYPERGLASS_HOME}/.local/bin"

# Copy python files from builder
COPY --from=builder --chown=hyperglass:hyperglass  ${HYPERGLASS_HOME}/.local/ ${HYPERGLASS_HOME}/.local/

# Run setup with default config dir (${HYPERGLASS_HOME}/hyperglass)
# Add dummy hyperglass.env.json
RUN \
  hyperglass setup -d && \
  echo '{"configFile": "/", "buildId": "0"}' > ${HYPERGLASS_HOME}/hyperglass/static/hyperglass.env.json

# We don't run build-ui here because it requires configuration, start will do build-ui with the right configuration
#RUN hyperglass build-ui

EXPOSE 8001
CMD \
  # Make hyperglass.env.json permanent
  ln -s ~/hyperglass/static/hyperglass.env.json /tmp/hyperglass.env.json && \
  hyperglass start