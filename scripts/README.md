# Scripts

Operational helpers for local development, bootstrapping, contract generation, and deployment support belong here.

Scripts should remain thin wrappers around documented operations. Keep secrets in private env files or secret stores, not in scripts.

Available helpers:

- `deploy-ui-fast.ps1` builds `elowen-ui` from the checked-out VPS workspace and restarts only that service through the VPS compose stack. This is the fast feedback loop for UI tweaks when you do not want to wait on a GHCR publish.
