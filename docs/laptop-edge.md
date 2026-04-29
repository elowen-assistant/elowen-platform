# Edge Client Runtime

This runbook describes the operator path for running `elowen-edge` as a durable Windows or Linux edge runtime with TOML configuration, provider-backed secret storage, a local TUI, and service-manager integration.

## Scope

This document covers:

- preparing a Windows laptop or Linux/VPS host to run `elowen-edge`
- migrating one legacy env file into TOML
- storing private edge trust material in Windows DPAPI-protected files or permission-checked Linux/container secret files
- using the TUI for setup, diagnostics, and service control
- installing persistent service startup through Windows Task Scheduler or Linux systemd
- validating device registration and remote dispatch

It does not cover exposing NATS publicly. The usual remote-laptop topology still reaches private NATS through an SSH tunnel unless the host is colocated with the orchestrator network.

## Files

- TOML template: [edge.toml.example](D:/Projects/elowen/elowen-edge/edge.toml.example)
- Edge runtime and TUI: [elowen-edge](D:/Projects/elowen/elowen-edge/README.md)
- Windows fallback helpers: [scripts/windows](D:/Projects/elowen/elowen-edge/scripts/windows)

## Prepare The Config

Build or download the `elowen-edge` executable, then create a local config:

```powershell
cargo build --release --manifest-path .\elowen-edge\Cargo.toml
Copy-Item .\elowen-edge\edge.toml.example .\elowen-edge\edge.toml
New-Item -ItemType Directory .\elowen-edge\secrets -Force
```

Generate per-device trust material:

```powershell
.\elowen-edge\target\release\elowen-edge.exe trust generate-keypair
```

On Windows, import the generated edge private key into a DPAPI-protected local file:

```powershell
.\elowen-edge\target\release\elowen-edge.exe trust import-key `
  --from .\elowen-edge\secrets\edge-signing-key.txt `
  --to .\elowen-edge\secrets\edge-signing-key.dpapi `
  --provider dpapi
```

Store the orchestrator public trust bundle in `secrets\orchestrator-trust.json`:

```json
[
  { "key_id": "current", "public_key": "<base64url-public-key>" }
]
```

On Linux, keep the edge private key in a mounted or service-owned file and restrict it to the service user before startup:

```bash
chmod 600 /etc/elowen/secrets/*
```

## Install On Windows

The normal Windows flow is to download and run the unsigned Inno Setup installer. Release packaging produces it with:

```powershell
.\elowen-edge\scripts\windows\New-ElowenEdgeInnoInstaller.ps1 -Release
```

Build hosts need Inno Setup 6:

```powershell
winget install --id JRSoftware.InnoSetup -e
```

The generated `dist\ElowenEdgeSetup.exe` installs the edge binary, helper scripts, TOML config, optional local secret files, scheduled task, Windows uninstall entry, and TUI shortcuts. For unattended UAT with an existing config and secret directory:

```powershell
.\elowen-edge\dist\ElowenEdgeSetup.exe `
  /CURRENTUSER `
  /CONFIGSOURCE="$PWD\elowen-edge\edge.toml" `
  /SECRETSOURCEDIR="$PWD\elowen-edge\secrets"
```

The installed scheduled task currently starts without an installer-managed tunnel. Use the TUI after installation if a tunnel-backed service configuration is needed. The older `Install-ElowenEdge.ps1` bootstrap installer remains available for debugging the lower-level install logic.

## Configure With The TUI

Open the TUI:

```powershell
.\elowen-edge\target\release\elowen-edge.exe tui --config .\elowen-edge\edge.toml
```

Use the first-run checklist to confirm:

- orchestrator API URL and NATS URL
- stable device id and display name
- repository roots, hidden repos, and explicit repo overlays
- Codex command and extra args
- trust bundle path and edge signing-key path
- service install state

Detailed edits happen in `edge.toml`; press `Shift+R` in the TUI to reload validation after editing.

## TOML Fields

Expected baseline values:

- `[orchestrator].api_url = "https://<PUBLIC_HOSTNAME>"`
- `[orchestrator].nats_url = "nats://127.0.0.1:4222"`
- `[device].id = "<stable unique device identifier>"`
- `[device].name = "<operator-visible label>"`
- `[repositories].allowed_roots = ["<parent directory containing git repos>"]`
- `[repositories].excluded_paths = ["<optional nested paths to skip>"]`
- `[repositories].hidden_repos = ["<optional repo names hidden from dispatch pickers>"]`
- `[repositories].workspace_root = "<workspace path>"`
- `[repositories].worktree_root = "<workspace path>/.elowen/worktrees"`
- `[runner].codex_command = "codex"`
- `[runner].codex_args = ["--model", "gpt-5.4"]`
- `[runner].sandbox_mode = "workspace"`
- `[trust].orchestrator_keys_path = "secrets/orchestrator-trust.json"`
- `[trust.edge_signing_key].provider = "dpapi"` and `[trust.edge_signing_key].path = "secrets/edge-signing-key.dpapi"` on Windows
- `[trust.edge_signing_key].provider = "file"` and `[trust.edge_signing_key].path = "secrets/edge-signing-key.txt"` on Linux/VPS/container hosts

On Windows, configure Codex with the command that works from a non-interactive background task. Prefer the npm shim discovered with:

```powershell
Get-Command codex.cmd
```

Use that absolute path in TOML:

```toml
[runner]
codex_command = 'C:\Users\<you>\AppData\Roaming\npm\codex.cmd'
codex_args = []
```

Avoid pointing at the Microsoft Store app location under `C:\Program Files\WindowsApps`; it may be visible but fail with `Access is denied` when the edge service starts.

`[repositories].allowed_roots` is the preferred repository declaration. The edge discovers nested git repositories under those trusted roots and advertises them during device registration. Keep `[repositories].allowed_repos` only as an explicit overlay for one-off additions or exceptions.

## Migrate From A Legacy Env File

If a host still has `edge.env.local`, import it once:

```powershell
.\elowen-edge\target\release\elowen-edge.exe config import-env `
  --env-file .\elowen-edge\edge.env.local `
  --config .\elowen-edge\edge.toml
```

After import, run only with `run --config`. The runtime no longer accepts `--env-file` or `ELOWEN_EDGE_ENV_FILE`.

## Run In The Foreground

```powershell
.\elowen-edge\target\release\elowen-edge.exe run --config .\elowen-edge\edge.toml
```

For Linux:

```bash
/usr/local/bin/elowen-edge run --config /etc/elowen/edge.toml
```

## Persistent Service Install

Windows uses Task Scheduler. Open the TUI and press `i` on the Service view to install the task, `s` to start, `x` to stop, and `r` to restart.

Linux and VPS hosts use systemd. When the TUI runs without permission to write `/etc/systemd/system`, it prints the unit content and target path so the operator can install with `sudo`.

Both service models run:

```bash
elowen-edge run --config <path>
```

The runtime writes local status to `[runtime].state_dir/status.json`, which the TUI reads for passive health reporting.

Install a Windows shortcut for opening the TUI without affecting the background edge service:

```powershell
.\elowen-edge\scripts\windows\Install-ElowenEdgeTuiShortcut.ps1 `
  -ConfigFile .\elowen-edge\edge.toml `
  -Release
```

Use `-Location StartMenu` if you prefer a Start Menu shortcut instead of a Desktop shortcut.

## Validation Checklist

1. Open the TUI and confirm the config parses.
2. Confirm secret-provider diagnostics pass.
3. Confirm Codex preflight passes, or intentionally accept simulated-runner mode for a test edge.
4. Install and start the service through the TUI.
5. Confirm the device appears in the remote UI or `GET /api/v1/devices`.
6. Create a manual capability job and confirm completion.
7. If repositories are configured, create a repository job and confirm worktree creation plus validation.
8. Restart the service and confirm the edge returns without an interactive terminal.

## Trust Lifecycle Rules

- Keep one TOML config and one secret backend/directory per device.
- Do not reuse a device id or private edge signing key on another machine.
- During edge key rotation, keep the same `[device].id`, set `[trust.previous_edge_signing_key]` only for the re-enrollment window, and remove it after the orchestrator admin UI confirms the rotated key.
- During orchestrator signer rotation, update `orchestrator-trust.json` with the approved overlap set before the API signer changes.
- If a device is revoked, stop the edge and do not keep retrying registration blindly.
- The TUI Diagnostics view reports structured trust failures when the API returns them. A revoked device/key means the orchestrator admin must clear revocation or re-enroll fresh material; a retired or unknown signer means the local `orchestrator-trust.json` is stale; a previous-key mismatch means the rotation window needs the prior edge key path restored.

## Operational Notes

- Keep `edge.toml` and `secrets/` out of git. DPAPI files are encrypted for the local Windows account but should still be treated as private operational material.
- A present `codex` command can still fail from a background service account; use TUI diagnostics to confirm the service user can run it.
- Trust rotation work is safest during a planned maintenance window because a mistrusted edge will stop registering until the mismatch is corrected.
