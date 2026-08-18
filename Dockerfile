FROM ubuntu:24.04

# Set environment variables for user and home directory
ENV USER=container
ENV HOME=/home/container
ENV DEBIAN_FRONTEND=noninteractive

# Set the working directory
WORKDIR /home/container

# Copy scripts to container
COPY ./entrypoint.sh /entrypoint.sh
COPY ./functions /functions
COPY ./files /files

# Install all required packages in a single layer to keep image size minimal.
# - tini:        proper init process — forwards SIGTERM/SIGINT to the MC server
# - curl/wget:   downloads (sdkman, server jars, MCJars API)
# - unzip:       read JAR manifests for existing-install detection
# - jq:          JSON parsing for MCJars API responses
# - util-linux:  lscpu (used by display.sh for hardware info)
# - procps:      free (RAM display)
# - git:         optional, for mod/plugin tooling
RUN apt-get update -y && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        tini \
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
        tzdata && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    adduser --disabled-password --home /home/container container && \
    chmod +x /entrypoint.sh

# Switch to non-root user
USER container

# Use tini as PID 1 so SIGTERM is properly forwarded to the Java process
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/bin/bash", "/entrypoint.sh"]
