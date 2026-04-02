# Laptop Edge

This runbook is the Slice 13 path for running `elowen-edge` as a repeatable standalone laptop process instead of an ad hoc terminal command.

## Scope

This document covers:

- preparing a laptop checkout to run `elowen-edge` against a remote orchestrator
- storing the edge configuration in a local env file
- starting the SSH tunnel and edge through a checked-in wrapper script
- optionally installing a per-user logon launcher on Windows
- validating device registration and remote job dispatch

This document does not cover:

- exposing NATS publicly
- real Codex runner setup
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
- `ELOWEN_EDGE_WORKSPACE_ROOT=<local workspace path>`
- `ELOWEN_EDGE_WORKTREE_ROOT=<local workspace path>\.elowen\worktrees`

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

## Operational notes

- The wrapper assumes NATS remains private on the VPS and is reached through SSH local port forwarding.
- `edge.env.local` should stay out of git.
- The Windows install helpers are Windows-specific because this is the current laptop host environment. The env-file support in `elowen-edge` itself is cross-platform.
- Task Scheduler may still be blocked by local policy on some machines. The Startup-folder launcher is the lower-friction default.
