# readiness-probe

Deployment `web` in namespace `broken-readiness` runs fine but is **never Ready**, so a Service would never send
it traffic and a rollout would never finish. Nothing crashes, which makes this one easy to miss.

Root cause: the app writes `/tmp/healthy`, but the readiness probe runs `cat /tmp/ready`.

## Apply

```bash
scripts/broken-workloads.sh apply readiness-probe
```

## What the agent should find

- `list_pods`: phase `Running`, READY `0/1`, RESTARTS `0`.
- `get_pod`: conditions `Ready False` and `ContainersReady False`; container `ready=false ... state=Running`.
- `list_events` (reason `Unhealthy`): `Readiness probe failed: cat: can't open '/tmp/ready': No such file or directory`.

A static scan does not catch this: the probe is well-formed, it just checks the wrong file.

## Expected fix

Point the probe at what the app actually exposes. [`fixed.yaml`](fixed.yaml) changes the probe to `cat /tmp/healthy`.

```bash
scripts/broken-workloads.sh fix readiness-probe
```
