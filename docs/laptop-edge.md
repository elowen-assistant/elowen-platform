# Laptop Edge

This runbook is the Slice 13 path for running `elowen-edge` as a repeatable standalone laptop process instead of an ad hoc terminal command.

## Scope

This document covers:

- preparing a laptop checkout to run `elowen-edge` against a remote orchestrator
- storing the edge configuration in a local env file
- starting the SSH tunnel and edge through a checked-in wrapper script
- optionally installing a per-user logon launcher on Windows
- validating device registration and remote job dispatch
- operating the Slice 34 edge-side trust lifecycle for rotation, revocation response, and multi-edge enrollment

This document does not cover:

- exposing NATS publicly
- chat-to-job automation
- in-thread completion replies

## Prerequisites

- a deployed VPS orchestrator from [vps-deployment.md](D:/Projects/elowen/elowen-platform/docs/vps-deployment.md)
- a laptop checkout that includes [elowen-edge](D:/Projects/elowen/elowen-edge/README.md)
- Rust installed locally if you plan to build the edge binary from source
- `ssh.exe` available on the laptop

## Files

- Env template: [edge.env.example](D:/Projects/elowen/elowen-edge/edge.env.example)
- Foreground and detached launcher: [Start-ElowenEdge.ps1](D:/Projects/elowen/elowen-edge/scripts/windows/Start-ElowenEdge.ps1)
- Startup-folder installer: [Install-ElowenEdgeStartup.ps1](D:/Projects/elowen/elowen-edge/scripts/windows/Install-ElowenEdgeStartup.ps1)
- Optional Task Scheduler installer: [Register-ElowenEdgeTask.ps1](D:/Projects/elowen/elowen-edge/scripts/windows/Register-ElowenEdgeTask.ps1)

## Prepare the local config

1. Build the edge binary from the repo root:

```powershell
cargo build --release --manifest-path .\elowen-edge\Cargo.toml
```

2. Copy the env template:

```powershell
Copy-Item .\elowen-edge\edge.env.example .\elowen-edge\edge.env.local
```

3. Edit `edge.env.local` so the values match the laptop checkout and target VPS.

Expected baseline values:

- `ELOWEN_API_URL=https://<PUBLIC_HOSTNAME>`
- `ELOWEN_NATS_URL=nats://127.0.0.1:4222`
- `ELOWEN_ALLOWED_REPO_ROOTS=<parent directory or directories that contain local git repos>`
- `ELOWEN_REPO_SCAN_EXCLUDE_PATHS=<optional nested paths under those roots to skip>`
- `ELOWEN_HIDDEN_REPOS=<optional repo names to keep out of dispatch pickers>`
- `ELOWEN_EDGE_WORKSPACE_ROOT=<local workspace path>`
- `ELOWEN_EDGE_WORKTREE_ROOT=<local workspace path>\.elowen\worktrees`
- `ELOWEN_SANDBOX_MODE=workspace`

`ELOWEN_ALLOWED_REPO_ROOTS` is the preferred repository declaration. The edge discovers nested git repositories under those trusted roots and advertises them during device registration. Use `ELOWEN_REPO_SCAN_EXCLUDE_PATHS` when a trusted parent contains subtrees that should never be scanned, and `ELOWEN_HIDDEN_REPOS` when a discovered repository should stay out of the orchestrator's selection UX. Keep `ELOWEN_ALLOWED_REPOS` only as an optional explicit overlay when you need a manual supplement or exception.

For trusted enrollment, also keep these values per device:

- `ELOWEN_DEVICE_ID=<stable unique device identifier for this machine only>`
- `ELOWEN_DEVICE_NAME=<operator-visible label for this machine only>`
- `ELOWEN_ORCHESTRATOR_PUBLIC_KEY=<current orchestrator signer or Slice 34 trust bundle delivered by the rollout plan>`
- `ELOWEN_EDGE_SIGNING_KEY=<this machine's private signing key>`

Treat `ELOWEN_DEVICE_ID` and `ELOWEN_EDGE_SIGNING_KEY` as device identity material. Do not reuse either value on a second machine.

To enable the real Codex runner, also set:

- `ELOWEN_CODEX_COMMAND=codex`

Optional extra flags belong in `ELOWEN_CODEX_ARGS_JSON`. Example:

```json
["--model","gpt-5.4"]
```

Do not include `exec`, `-C`, `--cd`, `-o`, or `--output-last-message`. `elowen-edge` manages those parts of the Codex invocation itself.

The edge runtime now enforces a worktree sandbox by default. Validation commands must stay inside the job worktree and cannot be launched through shell interpreters such as `powershell`, `cmd`, `sh`, or `bash`. Use `ELOWEN_SANDBOX_MODE=off` only for deliberate local debugging.

## Trust lifecycle operator rules

Follow these rules whenever you change trust material on a laptop edge:

- Keep one env file per device. Name it after the device and do not share it between laptops.
- Keep a separate operator note with the device ID, machine owner, current edge-key fingerprint, and last successful trusted registration time.
- Do not delete the device from the API to force re-enrollment. Use the explicit Slice 34 rotation or revocation path from the orchestrator side.
- Never copy another edge's private signing key onto this machine, even for testing.
- Before any trust change, make sure the machine is not actively running a job.

## Run in the foreground

This starts the SSH tunnel and keeps the edge attached to the current terminal:

```powershell
.\elowen-edge\scripts\windows\Start-ElowenEdge.ps1 `
  -EnvFile .\elowen-edge\edge.env.local `
  -TunnelUser <vps-user> `
  -TunnelHost <PUBLIC_HOSTNAME> `
  -Release
```

If the NATS tunnel already exists, skip tunnel startup:

```powershell
.\elowen-edge\scripts\windows\Start-ElowenEdge.ps1 `
  -EnvFile .\elowen-edge\edge.env.local `
  -SkipTunnel `
  -Release
```

## Run detached

This leaves both the tunnel and edge running in the background:

```powershell
.\elowen-edge\scripts\windows\Start-ElowenEdge.ps1 `
  -EnvFile .\elowen-edge\edge.env.local `
  -TunnelUser <vps-user> `
  -TunnelHost <PUBLIC_HOSTNAME> `
  -Release `
  -Detach
```

## Install a startup launcher on Windows

This creates a per-user Startup-folder launcher that runs the same wrapper at logon without requiring a scheduled task:

```powershell
.\elowen-edge\scripts\windows\Install-ElowenEdgeStartup.ps1 `
  -StartupName ElowenEdge `
  -EnvFile .\elowen-edge\edge.env.local `
  -TunnelUser <vps-user> `
  -TunnelHost <PUBLIC_HOSTNAME> `
  -Release
```

## Optional Task Scheduler path

If you prefer Task Scheduler and the laptop policy allows it, use:

```powershell
.\elowen-edge\scripts\windows\Register-ElowenEdgeTask.ps1 `
  -TaskName ElowenEdge `
  -EnvFile .\elowen-edge\edge.env.local `
  -TunnelUser <vps-user> `
  -TunnelHost <PUBLIC_HOSTNAME> `
  -Release
```

## Validation checklist

1. Start the laptop edge with the wrapper.
2. Confirm the device appears in the remote UI or `GET /api/v1/devices`.
3. Create a manual job from the remote UI.
4. Confirm the job is dispatched to the laptop and job events return to the orchestrator.
5. Stop and restart the wrapper to confirm the config file is sufficient without rebuilding the command manually.

## Slice 34 trust lifecycle procedures

### First trusted enrollment

1. Generate a fresh edge signing keypair for this machine only.
2. Set `ELOWEN_DEVICE_ID`, `ELOWEN_DEVICE_NAME`, `ELOWEN_ORCHESTRATOR_PUBLIC_KEY`, and `ELOWEN_EDGE_SIGNING_KEY` in the device's env file.
3. Start the wrapper and wait for trusted registration to complete.
4. Confirm the device appears in the UI with the expected trust state before sending work to it.

### Additional trusted edge enrollment

1. Start from a new env file rather than copying another laptop's full config.
2. Choose a new `ELOWEN_DEVICE_ID` and a unique display name for the additional machine.
3. Generate a new edge signing keypair on that machine.
4. Use the current orchestrator trust bundle from the rollout plan, including any staged signer needed during an orchestrator rotation window.
5. Start the wrapper and confirm the UI shows a new device record instead of changing an existing one.

### Edge signing key rotation and re-enrollment

1. Stop the edge after the current job queue is empty.
2. Generate a fresh edge signing keypair on the same machine.
3. Keep the existing `ELOWEN_DEVICE_ID` and device name unchanged.
4. Replace only `ELOWEN_EDGE_SIGNING_KEY` in the env file, then run the supported Slice 34 re-enrollment flow.
5. Confirm the API and UI still show the same device identity, with trust state updated to reflect the completed rotation.
6. Resume normal edge startup only after the trust state is correct.

Rollback:

- Restore the previous `ELOWEN_EDGE_SIGNING_KEY` for the same `ELOWEN_DEVICE_ID`.
- Re-run trusted registration.
- Do not create a second device identity to work around a failed rotation.

### Orchestrator signer rotation on the edge

1. Receive the updated orchestrator trust bundle before the VPS signer changes.
2. Update `ELOWEN_ORCHESTRATOR_PUBLIC_KEY` or the device's equivalent trust-bundle setting with the approved overlap set.
3. Restart the edge if required by the runtime packaging on that machine.
4. Request a fresh trusted registration challenge and confirm the edge accepts only the staged signer set.
5. After the platform rollout finishes, remove the retired signer from the local trust bundle.

### Revocation response on the edge

1. If the platform revokes this device's trust, stop the edge and do not keep retrying registration blindly.
2. Confirm with the operator whether the machine is being retired, re-imaged, or recovered with a new signing key.
3. If the machine is being recovered, wait for the orchestrator-side revocation to be visible, then generate a new edge signing keypair and follow the explicit re-enrollment procedure.
4. If the machine is retired, archive the local env file securely and remove any copied trust material from the host.

## Operational notes

- The wrapper assumes NATS remains private on the VPS and is reached through SSH local port forwarding.
- `edge.env.local` should stay out of git.
- The Windows install helpers are Windows-specific because this is the current laptop host environment. The env-file support in `elowen-edge` itself is cross-platform.
- Task Scheduler may still be blocked by local policy on some machines. The Startup-folder launcher is the lower-friction default.
- Trust rotation work is safest when done during a planned maintenance window because a mistrusted edge will stop registering until the trust mismatch is corrected.
