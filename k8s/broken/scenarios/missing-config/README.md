# missing-config

Two Deployments in namespace `broken-config` refer to configuration that was never created.

| Workload | Symptom | Root cause |
|----------|---------|------------|
| `config-api` | `CreateContainerConfigError`, container never starts | `env.valueFrom.configMapKeyRef` points at ConfigMap `app-config`, which does not exist |
| `secret-worker` | Stuck in `ContainerCreating` | A `secret` volume points at Secret `db-credentials`, which does not exist |

## Apply

```bash
scripts/broken-workloads.sh apply missing-config
# or: kubectl apply -f k8s/broken/scenarios/missing-config/broken.yaml
```

## What the agent should find

- `get_pod` on the `config-api` pod: `state=Waiting(CreateContainerConfigError)`, `restarts=0`.
- `get_pod` on the `secret-worker` pod: `state=Waiting(ContainerCreating)`.
- `list_events` for the namespace: `Error: configmap "app-config" not found` (reason `Failed`) and
  `MountVolume.SetUp failed for volume "creds" : secret "db-credentials" not found` (reason `FailedMount`).
- `get_configmap` for `app-config` returns a not-found error.

A static scan (`scan_manifest`) does not catch this: the manifest is valid; the objects it refers to are missing.

## Expected fix

Create the missing objects, or make the references `optional: true` if the app can run without them.
[`fixed.yaml`](fixed.yaml) creates ConfigMap `app-config` and Secret `db-credentials` (a placeholder value, not a
credential). The Deployments do not change; kubelet retries and both pods start.

```bash
scripts/broken-workloads.sh fix missing-config
```
