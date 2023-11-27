# This is the hyperglass user home directory, this is the base dir for configs and static files
ARG HYPERGLASS_HOME=/opt
# This is the base dire for venv and python binaries
ARG HYPERGLASS_BIN_PATH=/opt/app

# Developer suggests node 14, python 3.6 and ubuntu 18.04
# See: https://github.com/thatmattlove/hyperglass/blob/5e5acae4aa54e876940a889f94e44a61a333fe3b/README.md
FROM node:14-buster-slim AS base
ARG HYPERGLASS_HOME
ARG HYPERGLASS_BIN_PATH

ENV POETRY_NO_INTERACTION=1 \
    POETRY_VIRTUALENVS_IN_PROJECT=1 \
    POETRY_VIRTUALENVS_CREATE=1 \
    # 1.5.1 is the last version with python 3.7 support
    POETRY_VERSION=1.5.1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# install runtime dependencies (python3 zlib libjpeg wget)
RUN \
  apt-get update && \
  apt-get install wget zlib1g libjpeg62-turbo python3 -y --no-install-recommends && \
  rm -rf /var/lib/apt/lists/*

# Create user hyperglass and chown its home directory
RUN \
  adduser --disabled-password --gecos "" --shell /usr/sbin/nologin --home ${HYPERGLASS_HOME} hyperglass --uid 4001 && \
  chown hyperglass:hyperglass ${HYPERGLASS_HOME}


FROM base AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y build-essential libssl-dev zlib1g-dev libjpeg-dev git python3-dev python3-venv

# Download git source
RUN npx degit thatmattlove/hyperglass ${HYPERGLASS_BIN_PATH}

# Separate bin dir to avoid creating two dirs named hyperglass in ${HYPERGLASS_HOME}
WORKDIR ${HYPERGLASS_BIN_PATH}

# Install poetry
RUN wget -qO- https://install.python-poetry.org | python3 -

# Install hyperglass with poetry (faster than pip and fixes an issue with debian buster)
RUN $HOME/.local/bin/poetry install --only main --no-cache

# Create next folder
RUN mkdir ${HYPERGLASS_BIN_PATH}/hyperglass/ui/.next

FROM base AS app
USER hyperglass

# Add .venv/bin to PATH
ENV PATH="${PATH}:${HYPERGLASS_BIN_PATH}/.venv/bin"

# Copy python files from builder
COPY --from=builder --chown=hyperglass:hyperglass ${HYPERGLASS_BIN_PATH}/.venv ${HYPERGLASS_BIN_PATH}/.venv
COPY --from=builder --chown=hyperglass:hyperglass ${HYPERGLASS_BIN_PATH}/hyperglass ${HYPERGLASS_BIN_PATH}/hyperglass

# Run setup with default config dir (${HYPERGLASS_HOME}/hyperglass)
# Add dummy hyperglass.env.json
RUN \
  mkdir ${HYPERGLASS_HOME}/.cache && \
  hyperglass setup -d && \
  echo '{"configFile": "/", "buildId": "0"}' > ${HYPERGLASS_HOME}/hyperglass/static/hyperglass.env.json

# We don't run build-ui here because it requires configuration, start will do build-ui with the right configuration
#RUN hyperglass build-ui

EXPOSE 8001
CMD \
  # Make hyperglass.env.json permanent
  ln -s ~/hyperglass/static/hyperglass.env.json /tmp/hyperglass.env.json && \
  hyperglass start
