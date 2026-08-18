FROM ubuntu:noble

ENV USER=container
ENV HOME=/home/container
ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /home/container

# Copy scripts into the image
COPY ./entrypoint.sh /entrypoint.sh
COPY ./functions /functions
COPY ./files /files

# Step 1: Install system packages
# Split from adduser/chmod so build failures are easier to diagnose.
# tini is NOT included: launch.sh uses 'exec java ...' which replaces bash
# as PID 1, so Java directly receives SIGTERM from Pterodactyl. No wrapper needed.
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
 && rm -rf /var/lib/apt/lists/*

# Step 2: Create the container user and mark entrypoint executable
RUN adduser --disabled-password --home /home/container container \
 && chmod +x /entrypoint.sh

# Pterodactyl requires a non-root user
USER container

CMD ["/bin/bash", "/entrypoint.sh"]
