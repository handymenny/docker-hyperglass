# This is the hyperglass user home directory, this is the base dir for configs, static files and python binaries
ARG HYPERGLASS_HOME=/opt

# Some dependencies don't compile with python 3.10
FROM python:3.9-slim-bullseye AS base
ARG HYPERGLASS_HOME

# install dependencies (yarn nodejs zlib libjpeg wget)
RUN \
  apt-get update && \
  apt-get install wget gnupg2 zlib1g libjpeg62-turbo -y && \
  # hyperglass 1.0.4 only supports node 14. See: https://github.com/thatmattlove/hyperglass/issues/209
  echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_14.x bullseye main" > /etc/apt/sources.list.d/nodesource.list && \
  echo "deb [signed-by=/usr/share/keyrings/yarnkey.gpg] https://dl.yarnpkg.com/debian stable main" > /etc/apt/sources.list.d/yarn.list && \
  wget -qO- https://deb.nodesource.com/gpgkey/nodesource.gpg.key | gpg --dearmor | tee /usr/share/keyrings/nodesource.gpg >/dev/null && \
  wget -qO- https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | tee /usr/share/keyrings/yarnkey.gpg >/dev/null && \
  apt-get update && \
  # RUN dependencies
  apt-get install -y nodejs yarn && \
  rm -rf /var/lib/apt/lists/*

# Create user hyperglass and chown its home directory
RUN \
  adduser --disabled-password --gecos "" --shell /usr/sbin/nologin --home ${HYPERGLASS_HOME} hyperglass && \
  chown hyperglass:hyperglass ${HYPERGLASS_HOME}


FROM base AS builder
ARG HYPERGLASS_HOME

# Install build dependencies
RUN apt-get update && apt-get install -y build-essential libssl-dev zlib1g-dev libjpeg-dev git

# Download git source
RUN npx degit thatmattlove/hyperglass /hyperglass-src

# Build wheel with world writable cache
WORKDIR /hyperglass-src
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