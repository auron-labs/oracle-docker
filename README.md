# Oracle Docker

Docker image for running [`oracle serve`](https://github.com/steipete/oracle) with a built-in Chrome browser, Selenium, and noVNC.

This image is meant for remote browser mode: you run the container on a machine with Docker, sign into ChatGPT once inside the container's browser, and then point Oracle clients at the container with `--remote-host`.

## What It Includes

- `selenium/standalone-chrome` as the base image
- Chrome, VNC, and noVNC for interactive browser login
- `@steipete/oracle` installed from npm at build time
- `oracle serve` started automatically alongside the browser stack

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
  -p 4444:4444 \
  --shm-size=2g \
  -e ORACLE_SERVE_TOKEN=test-token \
  -v oracle-data:/home/seluser/.oracle \
  --name oracle \
  ghcr.io/auron-labs/oracle-docker:latest
```

Then:

1. Open `http://localhost:7900/?autoconnect=1&resize=scale`
2. Sign into ChatGPT in the Chrome window inside the container
3. Wait a few seconds for `oracle serve` to retry, or restart the container once
4. From another terminal, connect to the container with Oracle

Example client command:

```bash
npx -y @steipete/oracle --engine browser \
  --remote-host localhost:9473 \
  --remote-token test-token \
  -p "Reply with OK"
```

## First-Run Login Flow

On a fresh container there are no ChatGPT cookies yet. `oracle serve` will try to start, notice that login is required, open ChatGPT in the container browser, then exit.

That is expected.

The container keeps Selenium, Chrome, VNC, and noVNC running so you can complete login. After login:

- wait for the next automatic `oracle serve` retry, or
- restart the container once

Persist `/home/seluser/.oracle` so the login session survives future container restarts.

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
  -p 4444:4444 \
  --shm-size=2g \
  -e ORACLE_SERVE_TOKEN=test-token \
  -v oracle-data:/home/seluser/.oracle \
  --name oracle-test \
  oracle-docker:test
```

Watch logs:

```bash
docker logs -f oracle-test
```

Healthy first-run behavior looks like this:

- noVNC stays available at `http://localhost:7900`
- logs may show `oracle serve exited; retrying in 5s`
- after ChatGPT login, a retry succeeds and remote Oracle clients can connect

## Ports

| Port | Purpose |
|---|---|
| `9473` | `oracle serve` remote host |
| `4444` | Selenium Grid |
| `7900` | noVNC web UI |
| `5900` | Raw VNC |

## Configuration

### Environment Variables

| Variable | Default | Description |
|---|---|---|
| `ORACLE_HOME_DIR` | `/home/seluser/.oracle` | Oracle config, sessions, and browser state |
| `ORACLE_SERVE_HOST` | `0.0.0.0:9473` | Bind address for `oracle serve` |
| `ORACLE_SERVE_TOKEN` | empty | Optional token required by remote clients |
| `ORACLE_SERVE_RETRY_DELAY` | `5` | Seconds to wait before retrying `oracle serve` after exit |
| `ORACLE_ENGINE` | `browser` | Default Oracle engine inside the container |
| `ORACLE_BROWSER_CHROME_PATH` | `/usr/bin/google-chrome` | Chrome path used by Oracle |
| `SE_NODE_MAX_SESSIONS` | `3` | Maximum concurrent Selenium sessions |
| `SE_NODE_SESSION_TIMEOUT` | `300` | Selenium session timeout in seconds |
| `SE_VNC_NO_PASSWORD` | `1` | Disable VNC password on the container's VNC server |
| `SE_SCREEN_WIDTH` | `1920` | Virtual display width |
| `SE_SCREEN_HEIGHT` | `1080` | Virtual display height |

You can also pass any other Oracle-supported environment variables, including API keys when using API mode.

### Security Notes

- Set `ORACLE_SERVE_TOKEN` for any non-local use.
- Do not expose port `9473` publicly without authentication and network controls.
- Persist `/home/seluser/.oracle` carefully because it contains Oracle session data and browser state.

## Troubleshooting

### The container exits right away

Check the container logs:

```bash
docker logs -f oracle-test
```

If login is required, you should still be able to open noVNC and sign in. If the browser stack also exits, rebuild from the latest repo state.

### noVNC works but remote Oracle clients cannot connect

- confirm port `9473` is published
- confirm the client is using the correct `--remote-token`
- wait for `oracle serve` to restart after first-time login

### ChatGPT login does not persist

Make sure `/home/seluser/.oracle` is mounted to a persistent Docker volume.

## License

MIT
