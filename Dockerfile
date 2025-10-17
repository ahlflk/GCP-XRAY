# -----------------------------------------------------------
# Stage 1: Downloader (Use Alpine with curl, or install curl)
# -----------------------------------------------------------
FROM alpine:latest as downloader

# Install tools needed for download and decompression (curl and unzip)
RUN apk update && apk add --no-cache curl unzip

# Download Xray Core
# V1.8.6 is assumed as the version, but can be changed.
ENV XRAY_VERSION v1.8.6
ENV ARCH linux-64 

# Download Xray binary using curl and unzip it directly
RUN echo "Downloading Xray ${XRAY_VERSION}..." \
    && curl -L -o /tmp/xray.zip "https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}/Xray-${ARCH}.zip" \
    && unzip -q /tmp/xray.zip -d /usr/local/bin/ \
    && rm /tmp/xray.zip \
    && chmod +x /usr/local/bin/xray

# -----------------------------------------------------------
# Stage 2: Final Runtime Image (Minimal Alpine)
# -----------------------------------------------------------
FROM alpine:latest
LABEL maintainer="ahlflk"

# Install necessary packages for runtime (ca-certificates for TLS)
RUN apk update && apk add --no-cache ca-certificates tzdata

# Copy Xray executable from the downloader stage
COPY --from=downloader /usr/local/bin/xray /usr/local/bin/

# Copy the generated config file
# This file must be in the Docker build context (GCP-XRAY directory)
COPY config.json /usr/local/etc/xray/config.json

# Cloud Run requires 8080 by default
ENV PORT 8080
EXPOSE 8080

# Xray runs with the config file, listening on 8080
# Use 'exec' to ensure Xray is PID 1, allowing Cloud Run to handle signals correctly.
CMD ["/usr/local/bin/xray", "-config", "/usr/local/etc/xray/config.json"]
