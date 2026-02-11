FROM alpine:latest

# Install basic dependencies
RUN apk add --no-cache \
    bash \
    curl \
    tar \
    gzip \
    tzdata

ENV TZ=Asia/Shanghai

# Install s5cmd
ARG TARGETARCH
RUN case "${TARGETARCH}" in \
    "amd64") S5CMD_ARCH="Linux-64bit" ;; \
    "arm64") S5CMD_ARCH="Linux-arm64" ;; \
    *) echo "Unsupported architecture: ${TARGETARCH}"; exit 1 ;; \
    esac && \
    curl -L "https://github.com/peak/s5cmd/releases/download/v2.3.0/s5cmd_2.3.0_${S5CMD_ARCH}.tar.gz" | tar -xz && \
    mv s5cmd /usr/local/bin/s5cmd && \
    chmod +x /usr/local/bin/s5cmd

# Copy scripts
COPY backup.sh /backup.sh
COPY entrypoint.sh /entrypoint.sh

# Make scripts executable
RUN chmod +x /backup.sh /entrypoint.sh

# Create data directory
RUN mkdir -p /data

# Set entrypoint
ENTRYPOINT ["/entrypoint.sh"]
