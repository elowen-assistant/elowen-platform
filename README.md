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

Current operational docs include:

- [VPS Deployment](D:/Projects/elowen/elowen-platform/docs/vps-deployment.md)
- [Laptop Edge](D:/Projects/elowen/elowen-platform/docs/laptop-edge.md)
