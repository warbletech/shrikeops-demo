# Broken workloads for evaluators

These manifests are **valid Kubernetes YAML that fails at runtime**. They give evaluators something real to
diagnose with Heron Ops / Starling Lite on a local cluster (for example kind). This is different from
[`../bad/`](../bad/), which holds *misconfigurations* (privileged pod, root container, no limits, deprecated API)
for the ShrikeOps scanner to catch statically without running anything.

> Only apply these to a **disposable** cluster. `scripts/broken-workloads.sh` refuses to run unless the current
> kubectl context looks local (`kind-*`, `minikube`, `k3d-*`, `docker-desktop`, ...).

Every sample runs as non-root with no service account token, uses `busybox:1.36` or `python:3.12-alpine`, and
requests at most 32Mi memory (except the 64-CPU request in `unschedulable`, which is never scheduled). No hostPath,
no privileged containers.

## Core samples (namespace `demo`, used by the warble-army QUICKSTART)

| File | Symptom | Root cause | What the agent should find |
|------|---------|------------|----------------------------|
| [`crashloop.yaml`](crashloop.yaml) | `CrashLoopBackOff` | Container exits 1 ("db connection refused") | `get_pod_logs` shows the error; `get_pod` shows restarts rising |
| [`oom.yaml`](oom.yaml) | `OOMKilled` (exit 137), then `CrashLoopBackOff` | Allocates ~256 MiB under a 64 MiB limit | Restarts rising; `lastState.terminated.reason: OOMKilled` (see note) |
| [`bad-image-tag.yaml`](bad-image-tag.yaml) | `ErrImagePull` / `ImagePullBackOff` | Tag `busybox:1.36-does-not-exist` does not exist | `get_pod` shows `Waiting(ErrImagePull)` or `Waiting(ImagePullBackOff)`; `list_events` shows the pull failure for that tag |

All three scan as grade A (91.8, no high findings): they **break when they run**, not because they are badly written.

> **Note on the OOM sample:** Heron Ops `get_pod` prints each container's *current* state, not `lastState`. Between
> restarts it usually shows `state=Waiting(CrashLoopBackOff)` with a rising restart count. `Terminated(OOMKilled)`
> only shows up if the call lands in the short window after the kill. `list_events` for the namespace shows
> `BackOff` (restarting failed container), not an OOM event. To confirm the reason, run `kubectl -n demo describe pod -l app=memory-hog`
> (`Last State: Terminated, Reason: OOMKilled, Exit Code: 137`). `propose_remediation` has no built-in patch for
> OOM, and its generic `resources` patch sets a 256Mi limit, which is still too low for this workload.

Fixed versions are in [`fixed/`](fixed/): a container that stays up (stand-in for "the database is reachable
again"), a 384Mi memory limit, and an existing image tag.

## More scenarios (one namespace each)

| Scenario | Namespace | Symptom | Static scan catches it? |
|----------|-----------|---------|-------------------------|
| [`missing-config`](scenarios/missing-config/) | `broken-config` | `CreateContainerConfigError` / stuck `ContainerCreating` (missing ConfigMap and Secret) | No |
| [`unschedulable`](scenarios/unschedulable/) | `broken-scheduling` | `Pending`: 64-CPU request, nodeSelector that matches no node | No |
| [`readiness-probe`](scenarios/readiness-probe/) | `broken-readiness` | `Running` but never Ready (probe checks the wrong file) | No |
| [`hpa-no-requests`](scenarios/hpa-no-requests/) | `broken-hpa` | HPA cannot compute CPU utilisation (no CPU request). Needs metrics-server | Yes: kube-score `container-resources` |

Each scenario folder has `broken.yaml`, `fixed.yaml` and a README: the symptom, what the agent should find, and the fix.

## Use

The quickstart path (core samples only):

```bash
kind create cluster --name warble-eval        # or any disposable cluster
kubectl apply -f k8s/broken/namespace.yaml
kubectl apply -f k8s/broken/                  # not recursive: fixed/ and scenarios/ are not applied
kubectl -n demo get pods -w                   # wait ~1 minute for the failures to show
```

Or, with the helper script:

```bash
scripts/broken-workloads.sh apply              # everything; or: apply core | apply readiness-probe ...
scripts/broken-workloads.sh status
scripts/broken-workloads.sh fix readiness-probe   # apply a fixed/ version to check a proposed fix
scripts/broken-workloads.sh cleanup            # delete every sample namespace
```

Then ask your MCP client (Starling Lite or Heron Ops in `--mode=readonly`):

> What is unhealthy in namespace demo? Propose a fix without changing anything.

To see what an agent sees without an MCP client, call a tool directly:

```bash
MCP_SERVER="heron-ops --kubeconfig $HOME/.kube/config" \
  scripts/mcp-call.py list_events '{"namespace":"broken-config"}'
```

Clean up:

```bash
scripts/broken-workloads.sh cleanup
# or: kind delete cluster --name warble-eval
```

## How the samples are tested

[`.github/workflows/broken-workloads.yml`](../../.github/workflows/broken-workloads.yml) runs `kubeconform -strict`
and shellcheck. It then creates a kind cluster with metrics-server and runs
[`scripts/test-broken-workloads.sh`](../../scripts/test-broken-workloads.sh), which:

1. applies every sample and waits until each reaches the broken state described above,
2. calls the Heron Ops cluster tools (`get_pod`, `get_pod_logs`, `list_events`, `get_configmap`, `list_hpas`) and
   checks that they show the evidence these READMEs describe,
3. applies the `fixed/` versions and waits until every Deployment rolls out and the HPA reports CPU utilisation.
