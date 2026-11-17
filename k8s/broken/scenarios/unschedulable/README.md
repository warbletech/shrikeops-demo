# unschedulable

Two Deployments in namespace `broken-scheduling` can never be placed on a node, so their pods stay `Pending`.

| Workload | Root cause |
|----------|------------|
| `too-big` | Requests 64 CPUs, more than a laptop or kind node has |
| `wrong-node` | `nodeSelector: shrikeops-demo/disk: nvme` matches no node |

## Apply

```bash
scripts/broken-workloads.sh apply unschedulable
```

## What the agent should find

- `list_pods`: both pods in phase `Pending` with no node.
- `get_pod`: `PodScheduled False`, and no container status (the containers were never created).
- `list_events` (reason `FailedScheduling`): `0/1 nodes are available: 1 Insufficient cpu.` for `too-big`, and
  `... didn't match Pod's node affinity/selector` for `wrong-node`. The exact text depends on the node count and
  Kubernetes version.

A static scan does not flag either problem: a 64-CPU request and a nodeSelector are both valid on their own.

## Expected fix

Request what the workload needs, and select only labels that exist (or label a node). [`fixed.yaml`](fixed.yaml)
requests `10m` CPU for `too-big` and drops the nodeSelector from `wrong-node`.

```bash
scripts/broken-workloads.sh fix unschedulable
```
