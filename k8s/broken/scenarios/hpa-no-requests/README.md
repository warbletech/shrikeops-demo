# hpa-no-requests

HorizontalPodAutoscaler `api` in namespace `broken-hpa` targets 50% CPU utilisation, but the container in
Deployment `api` has **no CPU request**. Utilisation is a percentage of the request, so the HPA cannot compute it
and never scales.

> Needs [metrics-server](https://github.com/kubernetes-sigs/metrics-server). Without it every CPU HPA fails, broken
> or not, with an "unable to get metrics" error instead. On kind, install it and add `--kubelet-insecure-tls`
> (see `.github/workflows/broken-workloads.yml`). On minikube: `minikube addons enable metrics-server`.

## Apply

```bash
scripts/broken-workloads.sh apply hpa-no-requests
```

## What the agent should find

- `list_hpas`: the HPA `api` targeting `Deployment/api`, min 1, max 3. The tool shows replica counts only,
  not HPA conditions, so the cause comes from events.
- `list_events` (reason `FailedGetResourceMetric` / `FailedComputeMetricsReplicas`):
  `failed to get cpu utilization: missing request for cpu in container app of Pod ...`.
- This one is also visible statically: `scan_manifest` on [`broken.yaml`](broken.yaml) reports the kube-score
  finding `container-resources` ("CPU limit is not set; CPU request is not set"), which goes away in `fixed.yaml`.
- `propose_remediation` with `kind: Deployment`, `name: api`, `namespace: broken-hpa`, `container: app` and an
  issue such as `missing-resource-requests` returns a strategic-merge patch adding requests (`cpu: 50m`,
  `memory: 64Mi`) and limits (`cpu: 500m`, `memory: 256Mi`), which fixes the HPA.

## Expected fix

Give the container a CPU request. [`fixed.yaml`](fixed.yaml) adds `requests.cpu: 10m` and `limits.cpu: 50m`.
Within a minute or two the HPA reports a current CPU utilisation.

```bash
scripts/broken-workloads.sh fix hpa-no-requests
```
