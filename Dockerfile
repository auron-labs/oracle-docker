FROM selenium/standalone-chrome:latest

ARG ORACLE_VERSION=latest

USER root

# Install Node.js 24.x
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates curl gnupg && \
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_24.x nodistro main" > /etc/apt/sources.list.d/nodesource.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends nodejs && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Oracle
RUN npm install -g @steipete/oracle@${ORACLE_VERSION}

# Copy entrypoint
COPY docker-entrypoint.sh /opt/bin/docker-entrypoint.sh
RUN chmod +x /opt/bin/docker-entrypoint.sh

# Oracle serve port
EXPOSE 9473

# Selenium Grid, noVNC, VNC ports (from base image)
EXPOSE 4444
EXPOSE 7900
EXPOSE 5900

# Sane defaults for container use
ENV ORACLE_HOME_DIR=/home/seluser/.oracle
ENV ORACLE_SERVE_HOST=0.0.0.0
ENV ORACLE_SERVE_PORT=9473
ENV ORACLE_SERVE_TOKEN=
ENV ORACLE_SERVE_RETRY_DELAY=5
ENV ORACLE_ENGINE=browser
ENV ORACLE_BROWSER_MANUAL_LOGIN=1
ENV ORACLE_BROWSER_CHROME_PATH=/usr/bin/google-chrome
ENV SE_NODE_MAX_SESSIONS=3
ENV SE_NODE_SESSION_TIMEOUT=300
ENV SE_VNC_NO_PASSWORD=1
ENV SE_SCREEN_WIDTH=1920
ENV SE_SCREEN_HEIGHT=1080

USER seluser

ENTRYPOINT ["/opt/bin/docker-entrypoint.sh"]
