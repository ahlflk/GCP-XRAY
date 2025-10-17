# -----------------------------------------------------------
# Stage 1: Downloader
# -----------------------------------------------------------
FROM alpine:latest as downloader
RUN apk update && apk add --no-cache curl unzip

# Download Xray Core (Version 1.8.6 is recommended)
ENV XRAY_VERSION v1.8.6
ENV ARCH linux-64 

RUN echo "Downloading Xray ${XRAY_VERSION}..." \
    && curl -L -o /tmp/xray.zip "https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}/Xray-${ARCH}.zip" \
    && unzip -q /tmp/xray.zip -d /usr/local/bin/ \
    && rm /tmp/xray.zip \
    && chmod +x /usr/local/bin/xray

# -----------------------------------------------------------
# Stage 2: Final Runtime Image
# -----------------------------------------------------------
FROM alpine:latest
LABEL maintainer="ahlflk"

RUN apk update && apk add --no-cache ca-certificates tzdata

# Copy Xray executable from the downloader stage
COPY --from=downloader /usr/local/bin/xray /usr/local/bin/

# Copy the generated config file
COPY config.json /usr/local/etc/xray/config.json

# Cloud Run requires 8080 by default
ENV PORT 8080
EXPOSE 8080

# Xray runs with the config file, listening on 8080
CMD ["/usr/local/bin/xray", "-config", "/usr/local/etc/xray/config.json"]
