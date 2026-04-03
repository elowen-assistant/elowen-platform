# VPS Deployment

This runbook is the Slice 12 deployment path for a remotely hosted orchestrator with a laptop-hosted edge agent.

## Scope

This document covers:

- deploying `elowen-ui`, `elowen-api`, `elowen-notes`, `postgres`, and `nats` on one VPS
- pulling prebuilt service images from GitHub Container Registry instead of compiling Rust on the VPS
- exposing the UI and API publicly over HTTPS
- keeping Postgres, ArangoDB, and NATS off the public internet
- validating that a laptop-hosted `elowen-edge` can register and receive a manually created job from the remote UI

This document does not cover:

- chat-to-job automation
- in-thread assistant replies
- a polished laptop installer
- exposing NATS publicly

## Topology

- `caddy` terminates HTTPS and serves as the only public entrypoint
- `elowen-ui` is served behind `caddy`
- `elowen-api` is reachable through `https://<hostname>/api/...`
- `postgres`, `arangodb`, and `elowen-notes` stay private to the Docker network
- `nats` binds only to `127.0.0.1` on the VPS host
- the laptop edge reaches NATS through an SSH tunnel

## Prerequisites

- a Linux VPS with Docker Engine and Docker Compose plugin installed
- a DNS record for the chosen hostname pointing at the VPS
- ports `80/tcp` and `443/tcp` open to the VPS
- SSH access to the VPS from the laptop that will run `elowen-edge`
- the Elowen workspace checked out on the VPS

## Files

- Compose file: [docker-compose.vps.yml](D:/Projects/elowen/elowen-platform/compose/docker-compose.vps.yml)
- Reverse proxy config: [Caddyfile](D:/Projects/elowen/elowen-platform/compose/Caddyfile)
- NATS config: [nats-server.conf](D:/Projects/elowen/elowen-platform/compose/nats-server.conf)
- Environment template: [.env.vps.example](D:/Projects/elowen/elowen-platform/env/.env.vps.example)

## Environment setup

1. Copy [`.env.vps.example`](D:/Projects/elowen/elowen-platform/env/.env.vps.example) to a real env file on the VPS.
2. Replace `PUBLIC_HOSTNAME`, `ACME_EMAIL`, and all placeholder passwords.
3. If `ELOWEN_ARANGODB_USERNAME=root`, set `ELOWEN_ARANGODB_PASSWORD` to the same value as `ARANGO_ROOT_PASSWORD`.
4. Set `OPENAI_API_KEY` if you want Workflow #2 conversational replies enabled on the VPS-hosted orchestrator.
5. Set `ELOWEN_API_TAG`, `ELOWEN_NOTES_TAG`, and `ELOWEN_UI_TAG` to the image tags you want to deploy.
6. Keep the env file out of git.

Example:

```bash
cp elowen-platform/env/.env.vps.example elowen-platform/env/.env.vps
```

For reproducible deploys, pin the image tags to the exact submodule SHAs recorded in the workspace commit:

```bash
git -C elowen-api rev-parse HEAD
git -C elowen-notes rev-parse HEAD
git -C elowen-ui rev-parse HEAD
```

Then set:

```bash
ELOWEN_API_TAG=sha-<elowen-api sha>
ELOWEN_NOTES_TAG=sha-<elowen-notes sha>
ELOWEN_UI_TAG=sha-<elowen-ui sha>
```

If the GHCR packages are private, authenticate once on the VPS before the first pull:

```bash
docker login ghcr.io
```

## Deploy

From the workspace root on the VPS:

```bash
git checkout main
git pull --ff-only origin main
git submodule update --init --recursive

docker compose \
  --env-file elowen-platform/env/.env.vps \
  -f elowen-platform/compose/docker-compose.vps.yml \
  pull elowen-api elowen-ui elowen-notes

docker compose \
  --env-file elowen-platform/env/.env.vps \
  -f elowen-platform/compose/docker-compose.vps.yml \
  up -d
```

## Verify the VPS services

1. Open `https://<PUBLIC_HOSTNAME>/`.
2. Confirm the UI loads.
3. Confirm the API is reachable through the same origin:

```bash
curl https://<PUBLIC_HOSTNAME>/api/v1/threads
```

4. Inspect logs if anything fails:

```bash
docker compose \
  --env-file elowen-platform/env/.env.vps \
  -f elowen-platform/compose/docker-compose.vps.yml \
  logs -f
```

5. If Workflow #2 conversational chat is expected, verify `OPENAI_API_KEY` is present in the VPS env file and that `elowen-api` can reach `https://api.openai.com/v1`.
6. Confirm the running image references match the expected tags:

```bash
docker compose \
  --env-file elowen-platform/env/.env.vps \
  -f elowen-platform/compose/docker-compose.vps.yml \
  images
```

## Laptop edge validation

Keep NATS private and forward it to the laptop over SSH:

```bash
ssh -N -L 4222:127.0.0.1:4222 <user>@<PUBLIC_HOSTNAME>
```

Then run `elowen-edge` on the laptop with remote API and tunneled NATS:

```bash
$env:ELOWEN_API_URL="https://<PUBLIC_HOSTNAME>"
$env:ELOWEN_NATS_URL="nats://127.0.0.1:4222"
$env:ELOWEN_DEVICE_ID="elowen-laptop"
$env:ELOWEN_DEVICE_NAME="Elowen Laptop"
$env:ELOWEN_DEVICE_PRIMARY="true"
$env:ELOWEN_ALLOWED_REPOS="elowen-api,elowen-ui,elowen-edge,elowen-notes,elowen-platform"
$env:ELOWEN_DEVICE_CAPABILITIES="codex,git,build,test"
$env:ELOWEN_EDGE_WORKSPACE_ROOT="D:\Projects\elowen"
$env:ELOWEN_EDGE_WORKTREE_ROOT="D:\Projects\elowen\.elowen\worktrees"
elowen-edge
```

## Slice 12 validation checklist

1. Deploy the VPS stack successfully.
2. Open the remote UI over HTTPS.
3. Create a thread and post a message.
4. Start the SSH tunnel from the laptop to the VPS.
5. Start `elowen-edge` on the laptop.
6. Confirm the device appears in the UI or API.
7. Create a job from the remote UI.
8. Confirm the job is dispatched to the laptop and job events appear in the remote UI.

## Operational notes

- `nats` is intentionally not exposed on a public interface in this Slice 12 path.
- If the laptop disconnects, job dispatch will stall after probing or dispatch.
- `caddy` stores ACME state in the `caddy-data` volume.
- Rust and WASM builds should happen in GitHub Actions, not on the VPS.
- The current deployment is still single-node and local-first in spirit. It is enough to prove the remote split, not to claim production hardening.
