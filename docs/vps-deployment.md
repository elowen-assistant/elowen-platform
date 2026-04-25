# VPS Deployment

This runbook is the Slice 12 deployment path for a remotely hosted orchestrator with a laptop-hosted edge agent.

## Scope

This document covers:

- deploying `elowen-ui`, `elowen-api`, `elowen-notes`, `postgres`, and `nats` on one VPS
- pulling prebuilt service images from GitHub Container Registry instead of compiling Rust on the VPS
- exposing the UI and API publicly over HTTPS
- keeping Postgres, ArangoDB, and NATS off the public internet
- validating that a laptop-hosted `elowen-edge` can register and receive a manually created job from the remote UI
- operating the Slice 34 trust lifecycle for orchestrator rotation, edge rotation, revocation, and additional trusted edges

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
9. Set `ELOWEN_ORCHESTRATOR_SIGNING_KEY` and `ELOWEN_REQUIRE_TRUSTED_EDGE_REGISTRATION=true` when you want trusted edge registration enforced. Keep a separate operator-owned trust inventory that records the current orchestrator signer fingerprint, every enrolled device ID, the current edge key fingerprint for that device, and any revocation or rotation notes.
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

## Lower-impact deploys

For day-to-day VPS testing from a developer workstation, the default path should be the prebuilt image-transfer workflow:

```powershell
./elowen-platform/scripts/deploy-app-prebuilt.ps1
```

Use the VPS source-build workflow only if the prebuilt route is unavailable or debugging specifically requires it.

The cheapest VPS deploy path is:

1. compile binaries and static assets on a stronger machine or CI runner
2. assemble runtime-only container images from those finished artifacts
3. push the images to GHCR
4. let the VPS only `docker pull` and restart containers

That avoids Rust and WASM compilation on the VPS entirely.

Two lightweight runtime-only Dockerfiles are available:

- [elowen-api/Dockerfile.prebuilt](C:/Users/ericw/Projects/elowen/elowen-api/Dockerfile.prebuilt)
- [elowen-ui/Dockerfile.prebuilt](C:/Users/ericw/Projects/elowen/elowen-ui/Dockerfile.prebuilt)

The local helper script builds artifacts first, then packages those artifacts into images without compiling inside `docker build`:

```powershell
./elowen-platform/scripts/build-prebuilt-images.ps1 -Push
```

By default it:

1. runs `cargo build --release` for `elowen-api`
2. runs `trunk build --release` for `elowen-ui`
3. copies the finished outputs into each repo's `build/` directory
4. builds runtime-only images from `Dockerfile.prebuilt`
5. optionally pushes those images to GHCR

Useful variants:

```powershell
./elowen-platform/scripts/build-prebuilt-images.ps1 -ApiOnly -Push
./elowen-platform/scripts/build-prebuilt-images.ps1 -UiOnly -Push
./elowen-platform/scripts/build-prebuilt-images.ps1 -ApiTag sha-abc123 -UiTag sha-def456 -Push
```

After that, set the matching tags in `elowen-platform/env/.env.vps` and use the normal pull-based deploy flow on the VPS.

If you just need to refresh the full app from a dirty local workspace and do not want to push to GHCR, use the repeatable prebuilt app helper:

```powershell
./elowen-platform/scripts/deploy-app-prebuilt.ps1
```

That workflow:

1. builds the Linux `elowen-api` binary locally inside Docker
2. builds the `elowen-ui` artifact locally
3. packages runtime-only API and UI images locally
4. streams those images directly to the VPS with `docker load`
5. retags them as local VPS images
6. restarts `elowen-api` and `elowen-ui` without compiling on the VPS

If you only need one service, use the narrower helpers:

```powershell
./elowen-platform/scripts/deploy-api-prebuilt.ps1
./elowen-platform/scripts/deploy-ui-prebuilt.ps1
```

If you just need to refresh the VPS UI from a dirty local workspace and do not want to push to GHCR, use the repeatable prebuilt UI helper:

```powershell
./elowen-platform/scripts/deploy-ui-prebuilt.ps1
```

That workflow:

1. builds the UI artifact locally
2. packages a runtime-only UI image locally
3. streams that image directly to the VPS with `docker load`
4. retags it as a local VPS image
5. restarts `elowen-ui` without compiling on the VPS

There is a matching helper for `elowen-api` when you only need the API:

```powershell
./elowen-platform/scripts/deploy-api-prebuilt.ps1
```

That workflow:

1. builds the Linux `elowen-api` binary locally inside Docker
2. packages a runtime-only API image locally
3. streams that image directly to the VPS with `docker load`
4. retags it as a local VPS image
5. restarts `elowen-api` without compiling on the VPS

## Fast UI dev loop

For UI-only iteration, you can skip the GHCR publish step and build `elowen-ui` directly from the VPS checkout.

The override file is [docker-compose.vps.dev-ui.yml](D:/Projects/elowen/elowen-platform/compose/docker-compose.vps.dev-ui.yml), and the local helper is [deploy-ui-fast.ps1](D:/Projects/elowen/elowen-platform/scripts/deploy-ui-fast.ps1).

From the local workspace root:

```powershell
./elowen-platform/scripts/deploy-ui-fast.ps1
```

What this does:

1. Archives the local `elowen-ui` working tree, excluding `.git`.
2. Uploads that archive to a temporary path on the VPS.
3. Writes a temporary UI-only compose override on the VPS so the dirty platform checkout is left alone.
4. Builds only `elowen-ui` from that temporary source tree.
5. Restarts only the `elowen-ui` service.

Use the normal GHCR-tagged deploy path when you want a reproducible checkpoint shared with others. Use the fast loop only when you are intentionally trading VPS CPU for convenience during short-lived UI iteration.

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

Then configure `elowen-edge` on the laptop with remote API and tunneled NATS:

```toml
[orchestrator]
api_url = "https://<PUBLIC_HOSTNAME>"
nats_url = "nats://127.0.0.1:4222"

[device]
id = "elowen-laptop"
name = "Elowen Laptop"
primary = true
capabilities = ["codex", "git", "build", "test", "generic_jobs"]

[repositories]
workspace_root = "D:\\Projects\\elowen"
worktree_root = "D:\\Projects\\elowen\\.elowen\\worktrees"
allowed_roots = ["D:\\Projects"]
excluded_paths = ["D:\\Projects\\archive"]
hidden_repos = ["personal-scratch"]
allowed_repos = ["elowen-api"]

[runner]
codex_command = "codex"
sandbox_mode = "workspace"

[trust]
orchestrator_keys_path = "secrets\\orchestrator-trust.json"
edge_signing_key_path = "secrets\\edge-signing-key.txt"
```

Run the edge with:

```bash
elowen-edge run --config /path/to/edge.toml
```

`[repositories].allowed_roots` is the preferred way to expose repositories to the orchestrator. The edge discovers nested git repositories under those parent directories during registration, while `[repositories].excluded_paths` and `[repositories].hidden_repos` let each device trim that set before it reaches the UI selection flow. `[repositories].allowed_repos` remains available as an explicit overlay for one-off additions or exceptions.

Trusted edge registration is opt-in for rollout safety. When enabled on the API, an edge must first fetch an orchestrator-signed registration challenge, verify it against the pinned orchestrator public key, and attach an edge-signed proof to registration.

Generate compatible keypairs from a trusted workstation with:

```bash
elowen-edge trust generate-keypair
```

Use one generated private key as `ELOWEN_ORCHESTRATOR_SIGNING_KEY` on the VPS, and give the matching public key to edges in `secrets/orchestrator-trust.json`. Generate a separate keypair per edge device, put its private key in the file referenced by `[trust].edge_signing_key_path`, and let the API store the public key during trusted registration.

## Trust inventory

Keep an operator-maintained inventory for every trusted deployment change. At minimum, track:

- orchestrator signer fingerprint currently in production
- next orchestrator signer fingerprint staged for rotation
- each trusted `device_id`
- the current edge public-key fingerprint for each device
- trust state for each device: trusted, rotated, revoked, or pending follow-up
- who approved the last trust-changing action and when it happened

Do not treat the inventory as optional notes. It is the rollback map for trust lifecycle changes.

## Trust lifecycle runbooks

Slice 42 makes the orchestrator the authoritative trust lifecycle owner. Private
orchestrator signing keys still come from deployment configuration, but public
signer state, device trust state, and admin actions are visible through the API
and admin UI. Treat the device trust projection as the dispatch gate: `trusted`
devices may receive jobs, while `rotated`, `revoked`, `untrusted`, and
`needs_attention` devices stay blocked until an admin resolves them.

### Orchestrator signing key rotation

Use this sequence when replacing `ELOWEN_ORCHESTRATOR_SIGNING_KEY` without breaking trusted enrollment:

1. Generate a new Ed25519 keypair from a trusted workstation and record both old and new public-key fingerprints in the trust inventory.
2. Add the new private key to `ELOWEN_ORCHESTRATOR_SIGNING_KEYS`, deploy `elowen-api`, and mark the new public signer `staged` in the admin UI.
3. Distribute the new orchestrator public key to every enrolled edge before activation. During the overlap window, each edge should trust both the current signer and the staged next signer from the rollout bundle.
4. From one canary edge, request a trusted registration challenge and confirm it accepts the new signer without treating any unknown signer as valid.
5. Repeat the challenge and registration check from at least one still-unrotated edge and one already-updated edge. Do not remove the old signer until both classes succeed.
6. Promote the new signer to active in the admin UI only after every edge has consumed the new trust bundle and successful trusted registration has been observed for each active device cohort.
7. Remove the old signer from the edge trust bundle and the VPS rotation configuration in a separate cleanup deploy. Update the trust inventory immediately after the cleanup succeeds.

Rollback:

- Restore the old orchestrator signer as the active signer on the VPS.
- Re-publish the prior edge trust bundle so every device trusts the old signer again.
- Re-run canary trusted registration from one edge before resuming broader dispatch traffic.

Validation:

- A trusted registration challenge succeeds from a canary edge before and after cutover.
- No edge accepts a signer fingerprint outside the approved overlap set.
- Device trust state remains visible and unchanged in the UI except for the expected rotation metadata.

### Edge signing key rotation and trusted re-enrollment

Use this sequence when a single device needs a new signing key:

1. Drain or pause new work on the target device so rotation does not start mid-job.
2. Record the device's current `device_id`, display name, and current edge-key fingerprint from the trust inventory.
3. Generate a fresh edge trust keypair on that device. Never copy another device's signing key and never reuse the old private key on a second machine.
4. Keep the same `[device].id` and device name, replace only the secret file referenced by `[trust].edge_signing_key_path`, temporarily set `[trust].previous_edge_signing_key_path`, and start the trusted re-enrollment flow. Do not delete the existing device row or manually edit API trust tables.
5. Confirm the API records the replacement as a rotation or re-enrollment for the same device identity instead of a new anonymous device.
6. Confirm the rotation in the orchestrator admin UI after verifying the new fingerprint. Dispatch remains blocked while the device is `rotated`.
7. Verify the UI shows the device as trusted again, then remove the retired fingerprint from the active inventory and mark it as superseded.

Rollback:

- Restore the prior edge signing key on the same device.
- Re-run trusted registration for the same `device_id`.
- Confirm the API and UI return to the last known-good trust state before retrying the rotation.

Validation:

- The rotated device re-registers successfully with its original `[device].id`.
- Manual dispatch to that device is blocked while rotated and works only after admin confirmation.
- The old edge key can no longer be used as the active key after the new key is accepted.

### Revocation handling

Use revocation when a signer or device should stop being trusted immediately:

1. Record the incident reason, affected fingerprints, affected `device_id`, and the operator approving the change.
2. Revoke the trust material through the admin UI or API. Do not approximate revocation by deleting the device row.
3. Verify that new registrations and re-enrollment attempts using the revoked trust material are rejected.
4. Confirm the device trust state is visible as revoked in the UI and any operator notes or incident references are attached in the inventory.
5. If the device is being recovered rather than retired, generate a new edge keypair and clear revocation only after the replacement material is ready.

Validation:

- Registration attempts using revoked trust material fail deterministically.
- Operators can distinguish revoked trust from an ordinary offline device.
- The inventory contains the revocation timestamp and replacement plan, if any.

### Additional trusted edge enrollment

Use this sequence for second and third devices:

1. Assign a unique `[device].id`, human-readable device name, and dedicated edge signing keypair to the new machine before first startup.
2. Create a separate TOML config and secret directory per device. Never clone an existing machine's edge private key.
3. Populate the orchestrator trust bundle used for the current rollout window, including any staged signer needed for an active orchestrator rotation.
4. Start the edge and complete first-time trusted enrollment for that specific device.
5. Verify the UI shows a distinct device record, the correct repository inventory, and the expected trust state for the new edge.
6. Only after the new device is visible and healthy should you enable it for operator dispatch selection.

Validation:

- The new edge appears as a separate trusted device rather than replacing an existing one.
- Existing trusted devices keep their identity and trust state.
- Repository and branch choices remain attributable to the correct device in the UI.

## Slice 12 validation checklist

1. Deploy the VPS stack successfully.
2. Open the remote UI over HTTPS.
3. Create a thread and post a message.
4. Start the SSH tunnel from the laptop to the VPS.
5. Start `elowen-edge` on the laptop.
6. Confirm the device appears in the UI or API.
7. Create a job from the remote UI.
8. Confirm the job is dispatched to the laptop and job events appear in the remote UI.

## Slice 34 validation checklist

1. Perform a canary trusted registration from one active edge and capture the signer fingerprint it accepted.
2. Rotate the orchestrator signer using the overlap procedure and confirm trusted registration still works from a canary edge before and after cutover.
3. Rotate one edge signing key through the explicit re-enrollment path and confirm the device keeps the same identity.
4. Revoke one retired or test trust credential and confirm registration with that credential is rejected.
5. Enroll an additional edge with its own `device_id` and signing key and confirm it appears as a separate trusted device in the UI.
6. Confirm operators can distinguish trusted, rotated, and revoked states during manual UI review.

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
- Rust and WASM builds should happen in GitHub Actions or on a developer workstation, not on the VPS.
- The current deployment is still single-node and local-first in spirit. It is enough to prove the remote split, not to claim production hardening.
