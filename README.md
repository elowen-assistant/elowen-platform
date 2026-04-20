# elowen-platform

## Purpose

Shared platform repository for deployment topology, environment examples, contracts, schema drafts, operational scripts, and architecture notes used across Elowen services.

## Current Responsibilities

- define Docker Compose deployment inputs for local and VPS environments
- hold shared protobuf contracts and draft schema material
- document VPS deployment, laptop edge operation, and other operational runbooks
- keep architecture decision records and helper scripts alongside platform docs
- provide environment-file examples and migration scaffolding such as Kubernetes manifests

## Repository Layout

- `compose/` - local and VPS Compose stacks
- `contracts/` - shared protobuf definitions
- `db/` - schema drafts and database notes
- `docs/` - operational documentation
- `env/` - example environment files
- `adr/` - architecture decision records
- `k8s/` - Kubernetes migration scaffolding
- `scripts/` - operational helpers

## Runtime And Config Entrypoints

Common entrypoints:

```bash
docker compose -f compose/docker-compose.vps.yml config
docker compose -f compose/docker-compose.vps.yml up -d
```

For a faster UI-only VPS dev loop, there is also a compose override and helper script that sync the local `elowen-ui` working tree to a temporary VPS build context, then rebuild only `elowen-ui` instead of waiting on a published GHCR image:

```powershell
./scripts/deploy-ui-fast.ps1
```

Use the docs in `docs/` and the example files in `env/` to assemble service-specific runtime configuration.

## Local Verification

```bash
docker compose -f compose/docker-compose.vps.yml config
```

Review platform changes alongside the affected docs, env examples, and scripts.

## Related Docs

- `docs/vps-deployment.md`
- `docs/laptop-edge.md`
- `env/`
