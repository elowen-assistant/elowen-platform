# Kubernetes

This folder now contains a `base/` Kustomize entry point that mirrors the current Compose topology and gives the stack an explicit migration path beyond local-first deployment.

After the initial Slice 39 audit pass, the base manifests now track the current GHCR-backed service images and the post-Slice-38 API and edge configuration shape more closely than the older scaffolding did.

Kubernetes is still a migration and validation path rather than the active production deployment. The active deployment path remains Docker Compose on the VPS with prebuilt GHCR images.

Validation completed so far:

- `kubectl kustomize elowen-platform/k8s/base` renders cleanly.
- The validated base applies successfully to a local `kind` cluster.
- `postgres`, `nats`, and `arangodb` start successfully in-cluster with the current base manifests.
- `elowen-api`, `elowen-notes`, and `elowen-ui` also run successfully in-cluster once their images are available to the cluster.
- Private GHCR images are the first real deployment blocker: without registry credentials or preloaded images, the application deployments fail with `ImagePullBackOff`.

Known intentional gaps still under Slice 39:

- ingress / TLS termination is not modeled yet; the current base stops at in-cluster services
- secrets still use example placeholder values and must be replaced before any real deployment
- the trusted edge runtime is intentionally excluded from the validated in-cluster base and remains a separate device-side concern

Current real-deployment prerequisites for the Kubernetes path:

- create a real replacement for `k8s/base/secret.example.yaml`
- if the GHCR packages are private, create a cluster image-pull secret before deployment
- decide whether API auth will use the legacy `ELOWEN_UI_PASSWORD` fallback or an account-config secret mounted into the API pod
- replace the default `main` image tags with pinned image tags when you want a reproducible deployment checkpoint
- use a separate laptop or workstation edge runtime for repository execution and other device-scoped job handling; the validated Kubernetes base does not deploy `elowen-edge`
