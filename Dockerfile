FROM node:24-alpine3.21

ARG ORACLE_VERSION=latest

RUN printf '%s\n' \
    'https://mirrors.edge.kernel.org/alpine/v3.21/main' \
    'https://mirrors.edge.kernel.org/alpine/v3.21/community' \
    > /etc/apk/repositories

RUN apk add --no-cache \
    chromium \
    xvfb \
    x11vnc \
    novnc \
    websockify \
    dbus \
    nss \
    freetype \
    harfbuzz \
    ttf-freefont \
    font-noto-emoji \
    ca-certificates \
    bash \
    procps \
    jq

RUN printf '#!/bin/sh\nexec /usr/bin/chromium-browser --no-sandbox --disable-gpu --disable-dev-shm-usage "$@"\n' \
    > /usr/local/bin/chromium-no-sandbox && chmod +x /usr/local/bin/chromium-no-sandbox

RUN npm install -g @steipete/oracle@${ORACLE_VERSION}

RUN mkdir -p /tmp/.X11-unix && chmod 1777 /tmp/.X11-unix
RUN adduser -D -h /home/app -s /bin/bash app

COPY docker-entrypoint.sh /opt/docker-entrypoint.sh
RUN chmod +x /opt/docker-entrypoint.sh

EXPOSE 9473
EXPOSE 7900
EXPOSE 5900

ENV HOME=/home/app
ENV ORACLE_HOME_DIR=/home/app/.oracle
ENV ORACLE_SERVE_HOST=0.0.0.0
ENV ORACLE_SERVE_PORT=9473
ENV ORACLE_SERVE_TOKEN=
ENV ORACLE_SERVE_RETRY_DELAY=5
ENV ORACLE_ENGINE=browser
ENV ORACLE_BROWSER_MANUAL_LOGIN=1
ENV CHROME_PATH=/usr/local/bin/chromium-no-sandbox
ENV ORACLE_BROWSER_PROFILE_DIR=/home/app/.oracle/browser-profile
ENV ORACLE_BROWSER_CHROME_PATH=/usr/local/bin/chromium-no-sandbox
ENV DISPLAY=:99
ENV DISPLAY_WIDTH=1920
ENV DISPLAY_HEIGHT=1080

USER app

ENTRYPOINT ["/opt/docker-entrypoint.sh"]
