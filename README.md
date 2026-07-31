# ShrikeOps Demo

> Intentional good/bad Kubernetes manifests for **[ShrikeOps](https://github.com/warble-tech/shrikeops)** — the scanner that catches bugs and impales them on thorns.

Part of the [Warble Army](https://github.com/warble-tech/warble-army) flock · **[warbleoss.org](https://warbleoss.org)**

[![License](https://img.shields.io/badge/license-Apache--2.0-blue)](LICENSE)

---

## What this repo demonstrates

| Capability | Description |
|---|---|
| **Raw YAML scanning** | Deployment, Service, RBAC, NetworkPolicy fixtures |
| **Helm chart scanning** | `helm template` output piped to ShrikeOps |
| **Bad config detection** | Intentionally misconfigured manifests (root, privileged, deprecated APIs) |
| **CI pipeline** | GitHub Actions workflow to scan YAMLs on push/PR |
| **HTML report viewer** | Offline scan report rendered in browser |

Great for **`good-first-issue`** contributions: add fixtures, improve docs, fix scan scripts.

---

## Quick start (local CLI)

```bash
# From warble-army (or install shrikeops binary)
git clone --recurse-submodules https://github.com/warble-tech/warble-army.git
cd warble-army

# Scan a bad fixture (example — use your local shrikeops build)
./shrikeops/scanner/bin/shrikeops scan shrikeops-demo/k8s/bad/root-container.yaml \
  || shrikeops scan shrikeops-demo/k8s/bad/root-container.yaml

# Or use helper scripts in this repo
cd shrikeops-demo
./scripts/scan-all.sh   # if scripts point at a local binary / env
```

### Live MCP (readonly demo)

Pair findings with live cluster tools via Starling Lite:

```text
https://starling-ex.frakma.io/lite/mcp
```

---

## Repository layout

```
shrikeops-demo/
├── k8s/
│   ├── good/                   # Well-configured manifests
│   ├── bad/                    # Intentionally bad configs
│   └── helm/                   # Sample chart
├── scripts/                    # scan helpers
├── reports/                    # HTML report viewer
├── demo/                       # asciinema / static demo (if present)
└── docs/                       # GKE/EKS/GitHub App setup notes
```

---

## Docs

- [ShrikeOps](https://github.com/warble-tech/shrikeops)
- [Heron Ops](https://github.com/warble-tech/heron-ops)
- [Starling EX Community](https://github.com/warble-tech/warble-army/blob/main/docs/STARLING_EX_CE.md)
- [warbleoss.org](https://warbleoss.org)

Optional commercial SaaS (not required for demos): [warblecloud.com](https://warblecloud.com)

---

## License

Apache-2.0 — see [LICENSE](LICENSE).

## Security

Report vulnerabilities to **security@warblecloud.com** — see [SECURITY.md](SECURITY.md).
