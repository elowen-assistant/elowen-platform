# Kubernetes

This folder now contains a `base/` Kustomize entry point that mirrors the current Compose topology and gives the stack an explicit migration path beyond local-first deployment.

Kubernetes remains migration scaffolding. The active deployment path is still Docker Compose on the VPS with prebuilt GHCR images.
