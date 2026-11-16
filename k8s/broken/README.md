# Broken workloads for evaluators

These manifests are **valid Kubernetes YAML that fails at runtime**. They give evaluators something real to
diagnose with Heron Ops / Starling Lite on a local cluster (for example kind). This is different from
[`../bad/`](../bad/), which holds *misconfigurations* for the ShrikeOps scanner to catch statically.

| File | Symptom | Root cause | What the agent should find |
|------|---------|------------|----------------------------|
| [`crashloop.yaml`](crashloop.yaml) | `CrashLoopBackOff` | Container exits 1 ("db connection refused") | `get_pod_logs` shows the error, restart count rises |
| [`oom.yaml`](oom.yaml) | `OOMKilled` (exit 137), then `CrashLoopBackOff` | Allocates ~256 MiB under a 64 MiB limit | `get_pod` shows `lastState.terminated.reason: OOMKilled` |
| [`bad-image-tag.yaml`](bad-image-tag.yaml) | `ErrImagePull` / `ImagePullBackOff` | Tag `busybox:1.36-does-not-exist` does not exist | `list_events` shows the pull failure |

All three run in the `demo` namespace as non-root with resource limits, so a ShrikeOps scan is mostly clean (each scored grade A, 91.8, with no high findings on 16 Nov 2026, IST).
The point is that they **break when they run**, not that they are badly written.

## Use

```bash
kind create cluster --name warble-eval        # or any disposable cluster
kubectl apply -f k8s/broken/namespace.yaml
kubectl apply -f k8s/broken/
kubectl -n demo get pods -w                   # wait ~1 minute for the failures to show
```

Then ask your MCP client (Starling Lite in `--mode=readonly`):

> What is unhealthy in namespace demo? Propose a fix without changing anything.

Clean up:

```bash
kubectl delete namespace demo
# or: kind delete cluster --name warble-eval
```

> Only apply these to a disposable cluster. `oom.yaml` deliberately exhausts its memory limit.
