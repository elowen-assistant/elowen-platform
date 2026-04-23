# Kubernetes Experimental Manifests

This folder holds Kubernetes manifests that are intentionally outside the validated Slice 39 base topology.

Current contents:

- `elowen-edge.yaml`

Why `elowen-edge` is experimental:

- the current edge runtime is designed around trusted device identity, host-owned repository roots, and disposable git worktrees
- repository execution depends on access to real git checkouts rather than only empty in-cluster scratch space
- the supported operational story today is still a separate laptop or workstation edge that connects back to the orchestrator

Treat anything in this folder as exploratory only. Do not assume these manifests are part of the validated Kubernetes deployment path unless a later slice promotes them into `k8s/base`.
