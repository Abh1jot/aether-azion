FROM ubuntu:24.04

ENV USER=container
ENV HOME=/home/container
ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /home/container

COPY ./entrypoint.sh /entrypoint.sh
COPY ./functions /functions
COPY ./files /files

# Install dependencies in a single layer.
# tini is installed directly from GitHub releases (not apt) because the Ubuntu
# 24.04 Docker image does not enable the 'universe' repo by default, which
# causes exit code 127 (command not found) during apt-get install tini.
# - curl/wget:   downloads (sdkman, server jars, MCJars API)
# - unzip:       JAR manifest reads for existing-install detection
# - jq:          JSON parsing for MCJars API
# - git:         self-update pull from GitHub on every boot
# - util-linux:  lscpu for hardware info in display.sh
# - procps:      free command for RAM display
# - od:          PNG magic-byte check for server icon validation
RUN apt-get update -y \
 && apt-get install -y --no-install-recommends \
        curl \
        wget \
        zip \
        unzip \
        jq \
        git \
        coreutils \
        util-linux \
        procps \
        ca-certificates \
        tzdata \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* \
 && curl -fsSL https://github.com/krallin/tini/releases/download/v0.19.0/tini-$(dpkg --print-architecture) \
        -o /usr/local/bin/tini \
 && chmod +x /usr/local/bin/tini \
 && adduser --disabled-password --home /home/container container \
 && chmod +x /entrypoint.sh

# Switch to non-root user (required by Pterodactyl)
USER container

# tini as PID 1: forwards SIGTERM to the Java process so the MC server
# shuts down cleanly when Pterodactyl stops the container.
ENTRYPOINT ["/usr/local/bin/tini", "--"]
CMD ["/bin/bash", "/entrypoint.sh"]
