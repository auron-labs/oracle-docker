#!/bin/bash
set -euo pipefail

# Ensure ORACLE_HOME_DIR exists
mkdir -p "${ORACLE_HOME_DIR}"

# Start the base Selenium/Chrome/VNC stack via the original entrypoint
/opt/bin/entry_point.sh &
SELENIUM_PID=$!

# Build oracle serve command
ORACLE_SERVE_CMD=(
    oracle
    serve
    --host "${ORACLE_SERVE_HOST}"
    --port "${ORACLE_SERVE_PORT}"
)

if [ "${ORACLE_BROWSER_MANUAL_LOGIN:-1}" = "1" ] || [ "${ORACLE_BROWSER_MANUAL_LOGIN:-}" = "true" ]; then
    ORACLE_SERVE_CMD+=(--browser-manual-login)
fi

if [ -n "${ORACLE_SERVE_TOKEN}" ]; then
    ORACLE_SERVE_CMD+=(--token "${ORACLE_SERVE_TOKEN}")
fi

ORACLE_PID=""

start_oracle() {
    echo "Starting oracle serve on ${ORACLE_SERVE_HOST}:${ORACLE_SERVE_PORT}..."
    "${ORACLE_SERVE_CMD[@]}" &
    ORACLE_PID=$!
}

# Trap signals and forward to both processes
cleanup() {
    echo "Shutting down..."
    if [ -n "${ORACLE_PID}" ]; then
        kill -TERM "$ORACLE_PID" 2>/dev/null || true
        wait "$ORACLE_PID" 2>/dev/null || true
    fi
    kill -TERM "$SELENIUM_PID" 2>/dev/null || true
    wait "$SELENIUM_PID" 2>/dev/null || true
    exit 0
}
trap cleanup SIGTERM SIGINT

start_oracle

while kill -0 "$SELENIUM_PID" 2>/dev/null; do
    if ! kill -0 "$ORACLE_PID" 2>/dev/null; then
        echo "oracle serve exited; retrying in ${ORACLE_SERVE_RETRY_DELAY}s"
        sleep "${ORACLE_SERVE_RETRY_DELAY}"
        if ! kill -0 "$SELENIUM_PID" 2>/dev/null; then
            break
        fi
        start_oracle
    fi
    sleep 1
done

wait "$SELENIUM_PID"
EXIT_CODE=$?

if [ -n "${ORACLE_PID}" ]; then
    kill -TERM "$ORACLE_PID" 2>/dev/null || true
    wait "$ORACLE_PID" 2>/dev/null || true
fi

exit "$EXIT_CODE"
