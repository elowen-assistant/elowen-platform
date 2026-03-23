# Kubernetes Base

These manifests mirror the current Docker Compose topology as a starting point for Kubernetes migration.

Notes:

- They are intentionally local-first and conservative.
- Stateful dependencies are included as simple `StatefulSet` definitions so the stack shape is explicit.
- Secrets use placeholder values and must be replaced before real deployment.
- The edge agent assumes a writable shared workspace path and should be revisited before multi-node deployment.

Apply with:

```bash
kubectl apply -k elowen-platform/k8s/base
```
