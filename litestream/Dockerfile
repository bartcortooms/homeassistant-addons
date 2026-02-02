ARG BUILD_FROM
FROM ${BUILD_FROM}

# Install Litestream
ARG LITESTREAM_VERSION=0.3.13
RUN apk add --no-cache wget ca-certificates jq \
    && ARCH=$(uname -m) \
    && case "$ARCH" in \
         x86_64) LITESTREAM_ARCH="amd64" ;; \
         aarch64) LITESTREAM_ARCH="arm64" ;; \
         armv7l) LITESTREAM_ARCH="arm7" ;; \
         *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
       esac \
    && wget -q "https://github.com/benbjohnson/litestream/releases/download/v${LITESTREAM_VERSION}/litestream-v${LITESTREAM_VERSION}-linux-${LITESTREAM_ARCH}.tar.gz" -O /tmp/litestream.tar.gz \
    && tar -xzf /tmp/litestream.tar.gz -C /usr/local/bin \
    && rm /tmp/litestream.tar.gz \
    && chmod +x /usr/local/bin/litestream

# Copy s6-overlay service
COPY rootfs /
