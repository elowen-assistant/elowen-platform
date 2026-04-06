# elowen-platform

Shared platform repo for deployment, contracts, schema drafts, environment examples, architecture notes, and helper scripts.

## Contents

- `compose/` - local deployment stack
- `compose/docker-compose.vps.yml` - VPS-oriented deployment stack
- `contracts/` - protobuf definitions
- `db/` - draft database schemas
- `docs/` - shared platform documentation
- `env/` - example environment files
- `adr/` - architecture decision records
- `scripts/` - operational helpers

This repo is where cross-service assets live before they are promoted into service-owned implementations.

## Current Operational Baseline

- VPS deployment uses Docker Compose and prebuilt GHCR images for `elowen-api`, `elowen-notes`, and `elowen-ui`.
- Local/laptop execution uses a standalone `elowen-edge` process with env-file startup and a local NATS tunnel.
- Web UI access is protected by API-issued cookie sessions when `ELOWEN_UI_PASSWORD` is configured.
- Edge registration can require signed trust proof when `ELOWEN_REQUIRE_TRUSTED_EDGE_REGISTRATION=true`.
- Edge repository access is primarily declared through parent-directory discovery with optional explicit repo overlays.
- Kubernetes manifests remain migration scaffolding, not the active production deployment path.

Current operational docs include:

- [VPS Deployment](D:/Projects/elowen/elowen-platform/docs/vps-deployment.md)
- [Laptop Edge](D:/Projects/elowen/elowen-platform/docs/laptop-edge.md)
