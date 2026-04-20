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
5. Prefer local-account auth by placing a TOML file under `elowen-platform/env/` that contains named `viewer`, `operator`, and `admin` accounts, then set `ELOWEN_UI_AUTH_CONFIG_PATH` to the matching in-container path under `/run/elowen-env/`. Use [ui-auth.example.toml](D:/Projects/elowen/elowen-platform/env/ui-auth.example.toml) as the shape reference.
6. Keep `ELOWEN_UI_COOKIE_SECURE=true` for the HTTPS VPS deployment so session cookies are marked `Secure`.
7. Leave `ELOWEN_UI_PASSWORD` empty when using the account config. It remains available only as a legacy compatibility fallback that synthesizes one admin account.
8. If you intentionally use the legacy fallback instead of the account config, set `ELOWEN_UI_PASSWORD` and optionally `ELOWEN_UI_OPERATOR_LABEL`.
9. Optionally set `ELOWEN_ORCHESTRATOR_SIGNING_KEY` and `ELOWEN_REQUIRE_TRUSTED_EDGE_REGISTRATION=true` to require Slice 28 signed edge registration.
10. Set `ELOWEN_API_TAG`, `ELOWEN_NOTES_TAG`, and `ELOWEN_UI_TAG` to the image tags you want to deploy.
11. Keep the env file and any auth-config file out of git.

Example:

```bash
cp elowen-platform/env/.env.vps.example elowen-platform/env/.env.vps
```

Example account-auth path:

```bash
cp elowen-platform/env/ui-auth.example.toml elowen-platform/env/ui-auth.vps.toml
# Then set:
# ELOWEN_UI_AUTH_CONFIG_PATH=/run/elowen-env/ui-auth.vps.toml
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
3. If `ELOWEN_UI_AUTH_CONFIG_PATH` is set, confirm the sign-in screen accepts a configured username and password and that role-based UI affordances match the signed-in account.
4. If the legacy `ELOWEN_UI_PASSWORD` fallback is used instead, confirm the shared-password sign-in still works.
5. Confirm the API is reachable through the same origin:

```bash
curl https://<PUBLIC_HOSTNAME>/api/v1/threads
```

6. Inspect logs if anything fails:

```bash
docker compose \
  --env-file elowen-platform/env/.env.vps \
  -f elowen-platform/compose/docker-compose.vps.yml \
  logs -f
```

7. If Workflow #2 conversational chat is expected, verify `OPENAI_API_KEY` is present in the VPS env file and that `elowen-api` can reach `https://api.openai.com/v1`.
8. Confirm the running image references match the expected tags:

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
$env:ELOWEN_ALLOWED_REPO_ROOTS="D:\Projects"
# Optional explicit repo-name overlay for exceptions or supplements.
$env:ELOWEN_ALLOWED_REPOS="elowen-api"
$env:ELOWEN_DEVICE_CAPABILITIES="codex,git,build,test"
$env:ELOWEN_EDGE_WORKSPACE_ROOT="D:\Projects\elowen"
$env:ELOWEN_EDGE_WORKTREE_ROOT="D:\Projects\elowen\.elowen\worktrees"
# Optional Slice 28 trusted registration. Use the orchestrator public key that
# matches ELOWEN_ORCHESTRATOR_SIGNING_KEY, plus this edge's private signing key.
# $env:ELOWEN_ORCHESTRATOR_PUBLIC_KEY="<base64url-no-pad Ed25519 public key>"
# $env:ELOWEN_EDGE_SIGNING_KEY="<base64url-no-pad Ed25519 private key>"
elowen-edge
```

`ELOWEN_ALLOWED_REPO_ROOTS` is the preferred way to expose repositories to the orchestrator. The edge discovers nested git repositories under those parent directories during registration, while `ELOWEN_ALLOWED_REPOS` remains available as an explicit overlay for one-off additions or exceptions.

Trusted edge registration is opt-in for rollout safety. When enabled on the API, an edge must first fetch an orchestrator-signed registration challenge, verify it against the pinned orchestrator public key, and attach an edge-signed proof to registration.

Generate compatible keypairs from a trusted workstation with:

```bash
elowen-edge --generate-trust-keypair
```

Use one generated private key as `ELOWEN_ORCHESTRATOR_SIGNING_KEY` on the VPS, and give the matching public key to edges as `ELOWEN_ORCHESTRATOR_PUBLIC_KEY`. Generate a separate keypair per edge device, put its private key in `ELOWEN_EDGE_SIGNING_KEY`, and let the API store the public key during trusted registration.

## Slice 12 validation checklist

1. Deploy the VPS stack successfully.
2. Open the remote UI over HTTPS.
3. Create a thread and post a message.
4. Start the SSH tunnel from the laptop to the VPS.
5. Start `elowen-edge` on the laptop.
6. Confirm the device appears in the UI or API.
7. Create a job from the remote UI.
8. Confirm the job is dispatched to the laptop and job events appear in the remote UI.

## Slice 29 realtime recovery checklist

1. Sign in to the remote UI, select a thread and job, and enter unsent composer text.
2. Trigger background thread or job updates and confirm the selected thread, selected job, details panel state, transcript position, and composer text remain stable.
3. Interrupt realtime delivery by temporarily stopping or isolating `elowen-api`, then confirm the UI switches to a degraded realtime state while remaining usable under polling fallback.
4. Restore API connectivity and confirm the UI automatically reconnects, catches up thread/job state, and returns to a connected realtime state without forcing a full page reset.
5. Trigger `thread.changed`, `job.changed`, and `device.changed` flows and confirm the expected UI regions refresh without losing local interaction state.
6. Expire the UI session or sign out and confirm the UI transitions to a disconnected state and does not keep retrying realtime until the next successful sign-in.

## Operational notes

- `nats` is intentionally not exposed on a public interface in this Slice 12 path.
- If the laptop disconnects, job dispatch will stall after probing or dispatch.
- `caddy` stores ACME state in the `caddy-data` volume.
- Rust and WASM builds should happen in GitHub Actions, not on the VPS.
- The current deployment is still single-node and local-first in spirit. It is enough to prove the remote split, not to claim production hardening.
