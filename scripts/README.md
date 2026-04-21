# Scripts

Operational helpers for local development, bootstrapping, contract generation, and deployment support belong here.

Scripts should remain thin wrappers around documented operations. Keep secrets in private env files or secret stores, not in scripts.

Available helpers:

- `deploy-app-prebuilt.ps1` is the default dev VPS rollout path. It deploys `elowen-api` and `elowen-ui` through the prebuilt image-transfer workflow so the VPS does not compile either service.
- `deploy-ui-fast.ps1` builds `elowen-ui` from the checked-out VPS workspace and restarts only that service through the VPS compose stack. This is the fast feedback loop for UI tweaks when you do not want to wait on a GHCR publish.
- `build-prebuilt-images.ps1` builds local release artifacts first, then packages runtime-only images without compiling inside `docker build`.
- `deploy-api-prebuilt.ps1` builds a Linux `elowen-api` binary locally inside Docker, packages a runtime-only API image, streams it to the VPS, and restarts only `elowen-api` without compiling on the VPS.
- `deploy-ui-prebuilt.ps1` builds a prebuilt `elowen-ui` image locally, streams it to the VPS with `docker load`, retags it as a local-only image there, and restarts `elowen-ui` without compiling on the VPS.
