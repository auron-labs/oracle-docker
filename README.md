# Oracle Docker

Docker image for running [`oracle serve`](https://github.com/steipete/oracle) with a built-in Chromium browser and noVNC.

This image is meant for remote browser mode: you run the container on a machine with Docker, sign into ChatGPT once inside the container's browser, and then point Oracle clients at the container with `--remote-host`.

## What It Includes

- Alpine Linux base with Chromium, Xvfb, x11vnc, VNC, and noVNC
- `@steipete/oracle` installed from npm at build time
- `oracle serve` started automatically alongside the GUI/VNC stack

## Quick Start

Pull the published image:

```bash
docker pull ghcr.io/auron-labs/oracle-docker:latest
```

Run it with a persistent Oracle data volume and a token for remote access:

```bash
docker run --rm -it \
  -p 9473:9473 \
  -p 7900:7900 \
  --shm-size=2g \
  -e ORACLE_SERVE_TOKEN=test-token \
  -v oracle-data:/home/app/.oracle \
  --name oracle \
  ghcr.io/auron-labs/oracle-docker:latest
```

Then:

1. Open `http://localhost:7900/vnc.html?autoconnect=1&resize=scale`
2. Sign into ChatGPT in the Chromium window inside the container
3. Wait a few seconds for `oracle serve` to retry, or restart the container once
4. From another terminal, connect to the container with Oracle

Example client command:

```bash
npx -y @steipete/oracle --engine browser \
  --remote-host localhost:9473 \
  --remote-token test-token \
  -p "Reply with OK"
```

Or put the remote defaults in `~/.oracle/config.json` so you do not need to repeat the flags each time:

```json
{
  "engine": "browser",
  "browser": {
    "remoteHost": "localhost:9473",
    "remoteToken": "test-token"
  }
}
```

Then you can run Oracle with just:

```bash
npx -y @steipete/oracle -p "Reply with OK"
```

## First-Run Login Flow

On a fresh container there are no ChatGPT cookies yet. `oracle serve` launches Chromium (via a `--no-sandbox` wrapper required for container environments) and opens ChatGPT. Because no session exists, login is required and `oracle serve` exits.

That is expected. The entrypoint retries `oracle serve` automatically every 5 seconds.

The container keeps Xvfb, x11vnc, and noVNC running so you can complete login through the VNC session. After login, the next automatic retry picks up the active session and remote Oracle clients can connect.

Persist `/home/app/.oracle` so the login session survives future container restarts.
This image passes `--manual-login --manual-login-profile-dir /home/app/.oracle/browser-profile` explicitly to `oracle serve` so first-run login and later remote runs use the same Chromium profile directory.

## Test Run

Build locally:

```bash
docker build --build-arg ORACLE_VERSION=0.14.0 -t oracle-docker:test .
```

Run locally:

```bash
docker run --rm -it \
  -p 9473:9473 \
  -p 7900:7900 \
  --shm-size=2g \
  -e ORACLE_SERVE_TOKEN=test-token \
  -v oracle-data:/home/app/.oracle \
  --name oracle-test \
  oracle-docker:test
```

Watch logs:

```bash
docker logs -f oracle-test
```

Healthy first-run behavior looks like this:

- noVNC stays available at `http://localhost:7900/vnc.html`
- raw VNC stays available on port `5900`
- a Chromium window opens in VNC showing the ChatGPT login page
- logs show `oracle serve exited; retrying in 5s`
- after you complete ChatGPT login in VNC, the next retry succeeds and remote Oracle clients can connect

## Ports

| Port | Purpose |
|---|---|
| `9473` | `oracle serve` remote host |
| `7900` | noVNC web UI |
| `5900` | Raw VNC |

## Configuration

### Environment Variables

| Variable | Default | Description |
|---|---|---|
| `ORACLE_HOME_DIR` | `/home/app/.oracle` | Oracle config, sessions, and browser state |
| `HOME` | `/home/app` | Home directory used by Oracle and Chromium path resolution |
| `ORACLE_SERVE_HOST` | `0.0.0.0` | Bind host for `oracle serve` |
| `ORACLE_SERVE_PORT` | `9473` | Bind port for `oracle serve` |
| `ORACLE_SERVE_TOKEN` | empty | Optional token required by remote clients |
| `ORACLE_SERVE_RETRY_DELAY` | `5` | Seconds to wait before retrying `oracle serve` after exit |
| `ORACLE_ENGINE` | `browser` | Default Oracle engine inside the container |
| `ORACLE_BROWSER_MANUAL_LOGIN` | `1` | Use Oracle's persistent manual-login browser profile instead of cookie copy |
| `ORACLE_BROWSER_PROFILE_DIR` | `/home/app/.oracle/browser-profile` | Persistent Chromium profile used by Oracle manual-login mode |
| `ORACLE_BROWSER_CHROME_PATH` | `/usr/local/bin/chromium-no-sandbox` | Chromium wrapper with `--no-sandbox` for container use |
| `DISPLAY` | `:99` | X11 display used by Xvfb |
| `DISPLAY_WIDTH` | `1920` | Virtual display width |
| `DISPLAY_HEIGHT` | `1080` | Virtual display height |

You can also pass any other Oracle-supported environment variables, including API keys when using API mode.

### Security Notes

- Set `ORACLE_SERVE_TOKEN` for any non-local use.
- Do not expose port `9473` publicly without authentication and network controls.
- Persist `/home/app/.oracle` carefully because it contains Oracle session data and browser state.

## Troubleshooting

### The container exits right away

Check the container logs:

```bash
docker logs -f oracle-test
```

If login is required, you should still be able to open noVNC and sign in. If the Xvfb or VNC stack also exits, rebuild from the latest repo state.

### noVNC works but remote Oracle clients cannot connect

- confirm port `9473` is published
- confirm the client is using the correct `--remote-token`
- wait for `oracle serve` to restart after first-time login

### ChatGPT login does not persist

Make sure `/home/app/.oracle` is mounted to a persistent Docker volume.

### Bind-mounted folder shows permission denied

The container starts as root, fixes ownership on `ORACLE_HOME_DIR`, then runs Oracle and the GUI stack as the `app` user. If you bind-mount a host folder, point it at `/home/app/.oracle` so the entrypoint can prepare `/home/app/.oracle/browser-profile` before Oracle starts.

## License

MIT
