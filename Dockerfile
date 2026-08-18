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

# Step 2: Create the container user and mark entrypoint executable.
# useradd is part of the base 'passwd' package (always present).
# chown /functions so the container user can write to it — this is
# required for the GitHub self-update (cp -r) to succeed on every boot.
RUN useradd --create-home --home-dir /home/container --shell /bin/bash container \
 && chown -R container:container /functions /entrypoint.sh

# Pterodactyl requires a non-root user
USER container

CMD ["/bin/bash", "/entrypoint.sh"]
