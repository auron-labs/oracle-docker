#!/bin/bash
set -euo pipefail

APP_USER=${APP_USER:-app}
APP_GROUP=${APP_GROUP:-app}

run_as_app() {
    su-exec "${APP_USER}:${APP_GROUP}" "$@"
}

mkdir -p "${ORACLE_HOME_DIR}"

if [ "$(id -u)" -eq 0 ]; then
    chown -R "${APP_USER}:${APP_GROUP}" "${ORACLE_HOME_DIR}"
fi

XVFB_PID=""
X11VNC_PID=""
WEBSOCKIFY_PID=""
ORACLE_PID=""

cleanup() {
    echo "Shutting down..."
    for pid in "$ORACLE_PID" "$WEBSOCKIFY_PID" "$X11VNC_PID" "$XVFB_PID"; do
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            kill -TERM "$pid" 2>/dev/null || true
        fi
    done
    for pid in "$ORACLE_PID" "$WEBSOCKIFY_PID" "$X11VNC_PID" "$XVFB_PID"; do
        if [ -n "$pid" ]; then
            wait "$pid" 2>/dev/null || true
        fi
    done
    exit 0
}
trap cleanup SIGTERM SIGINT

echo "Starting Xvfb on display ${DISPLAY}..."
run_as_app Xvfb "${DISPLAY}" -screen 0 "${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}x24" -ac +extension GLX +render -noreset &
XVFB_PID=$!

sleep 1

run_as_app x11vnc -display "${DISPLAY}" -forever -shared -nopw -rfbport 5900 -o /tmp/x11vnc.log &
X11VNC_PID=$!
echo "x11vnc started (pid ${X11VNC_PID})"

run_as_app websockify --web /usr/share/novnc 7900 localhost:5900 &
WEBSOCKIFY_PID=$!
echo "noVNC websocket proxy started on port 7900 (pid ${WEBSOCKIFY_PID})"

start_oracle() {
    local cmd=(oracle serve --host "${ORACLE_SERVE_HOST}" --port "${ORACLE_SERVE_PORT}")

    if [ "${ORACLE_BROWSER_MANUAL_LOGIN:-1}" = "1" ] || [ "${ORACLE_BROWSER_MANUAL_LOGIN:-}" = "true" ]; then
        cmd+=(--manual-login --manual-login-profile-dir "${ORACLE_BROWSER_PROFILE_DIR}")
    fi

    if [ -n "${ORACLE_SERVE_TOKEN:-}" ]; then
        cmd+=(--token "${ORACLE_SERVE_TOKEN}")
    fi

    echo "Starting oracle serve on ${ORACLE_SERVE_HOST}:${ORACLE_SERVE_PORT}..."
    run_as_app "${cmd[@]}" &
    ORACLE_PID=$!
}

start_oracle

while true; do
    for pid in "$XVFB_PID" "$X11VNC_PID" "$WEBSOCKIFY_PID"; do
        if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
            echo "Required process ${pid} exited unexpectedly; shutting down."
            cleanup
        fi
    done

    if ! kill -0 "$ORACLE_PID" 2>/dev/null; then
        echo "oracle serve exited; retrying in ${ORACLE_SERVE_RETRY_DELAY}s"
        sleep "${ORACLE_SERVE_RETRY_DELAY}"
        start_oracle
    fi

    sleep 1
done
