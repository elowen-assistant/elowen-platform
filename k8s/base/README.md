# Kubernetes Base

These manifests mirror the current Docker Compose topology as a starting point for Kubernetes migration.

Notes:

- They are intentionally local-first and conservative.
- Stateful dependencies are included as simple `StatefulSet` definitions so the stack shape is explicit.
- Secrets use placeholder values and must be replaced before real deployment.
- The service images now align with the current GHCR-backed `main` defaults rather than older `:latest` placeholders.
- API config now reflects the current auth and trusted-registration surface more closely, but real secret values still need cluster-specific wiring.
- The validated base intentionally excludes `elowen-edge`. Repository execution remains a separate trusted device runtime rather than an in-cluster workload in the current supported topology.
- These manifests are being audited and validated in Slice 39; do not treat them as equivalent to the existing VPS Compose deployment until that validation is complete.

Current validation status:

- Rendered successfully with `kubectl kustomize`.
- Applied successfully to a local `kind` cluster during Slice 39 validation.
- Stateful infrastructure (`postgres`, `nats`, `arangodb`) reached running state as-is.
- Application workloads (`elowen-api`, `elowen-notes`, `elowen-ui`) also reached running state once the images were made available inside the cluster.
- The first concrete rollout failure on a fresh cluster was private GHCR access, not manifest shape or service wiring.

Deployment-input expectations:

- Replace `secret.example.yaml` with a real secret manifest or an external secret workflow before any apply.
- If GHCR packages are private, create an image pull secret in the target namespace before rollout.
- By default the base uses `main` image tags. For reproducible deploys, override the `images` block in `kustomization.yaml` with pinned `sha-...` tags that match the intended service revisions.
- For API auth, choose one of these two modes:
  - legacy fallback: set `ELOWEN_UI_PASSWORD` in the main secret and leave `ELOWEN_UI_AUTH_CONFIG_PATH` empty
  - account config: create a secret named `elowen-ui-auth-config` with a `ui-auth.toml` key, mount it at `/run/elowen-env/ui-auth.toml`, and set `ELOWEN_UI_AUTH_CONFIG_PATH=/run/elowen-env/ui-auth.toml`
- Trusted registration inputs remain optional until the Kubernetes validation path explicitly decides to enforce them.
- If you need `elowen-edge` experimentation in Kubernetes anyway, treat it as unsupported exploratory work rather than part of the validated Slice 39 base.

Apply with:

```bash
kubectl apply -k elowen-platform/k8s/base
```

This base deploys:

- `postgres`
- `nats`
- `arangodb`
- `elowen-notes`
- `elowen-api`
- `elowen-ui`
