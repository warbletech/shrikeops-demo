# 🦅 KestrelOps Demo Repository

> **Production-grade Kubernetes manifest scanning via [KestrelOps](https://warblecloud.com/kestrel)**  
> Scan Helm charts, raw YAML, and live GKE/EKS/AKS clusters. Get scored security reports as a SaaS API.

[![KestrelOps Scan](https://img.shields.io/badge/KestrelOps-Scan%20Passing-00c853?style=flat-square&logo=kubernetes)](https://warblecloud.com/kestrel)
[![GitHub Checks](https://img.shields.io/badge/GitHub%20Checks-Enabled-0076D6?style=flat-square&logo=github)](https://warblecloud.com/kestrel/github)
[![CI Scan](https://github.com/avinashetrx/kestrelops-demo/actions/workflows/kestrelops-scan.yml/badge.svg)](https://github.com/avinashetrx/kestrelops-demo/actions/workflows/kestrelops-scan.yml)
[![Demo](https://img.shields.io/badge/▶%20Live%20Demo-Watch%20Now-6366f1?style=flat-square)](https://avinashetrx.github.io/kestrelops-demo/demo/)

---

## ▶ Terminal Demo

> **[Watch the full interactive demo →](https://avinashetrx.github.io/kestrelops-demo/demo/)**

[![KestrelOps Terminal Demo](https://img.shields.io/badge/asciinema-Watch%20Demo-d40000?style=flat-square&logo=asciinema)](https://avinashetrx.github.io/kestrelops-demo/demo/)

The demo walks through:
1. Scanning a **hardened** Deployment (score A, 94)
2. Scanning a **root container** — 2 CRITICAL findings caught
3. Scanning **deprecated API versions** via Pluto
4. Rendering a **Helm chart** and scanning the output
5. Running **scan-all** to get a full summary table

---

## What This Repo Demonstrates

| Capability | Description |
|---|---|
| **Raw YAML scanning** | Kubernetes Deployment, Service, RBAC, NetworkPolicy manifests |
| **Helm chart scanning** | `helm template` output piped to KestrelOps |
| **Bad config detection** | Intentionally misconfigured manifests to show findings |
| **GitHub PR Checks** | Automatic scan on every PR via KestrelOps webhook |
| **CI pipeline** | GitHub Actions workflow scanning all YAMLs on push |
| **GKE live cluster** | Export running workloads from GKE and scan them |
| **EKS / AKS** | Same pattern for AWS and Azure clusters |
| **HTML report viewer** | Offline scan report rendered in browser |

---

## Quick Start — Scan a Manifest

```bash
# Scan any YAML file against the KestrelOps API (free tier: 3 scans/day)
curl -s -X POST https://warblecloud.com/api/kestrel-scan \
  -H "Content-Type: application/json" \
  -d "{\"manifest\": \"$(cat k8s/good/deployment.yaml | base64 -w0 | base64 -d)\", \"source\": \"deployment.yaml\"}" \
  | jq .

# Or use the helper script (handles encoding for you)
./scripts/scan.sh k8s/bad/root-container.yaml
```

### What You Get Back

```json
{
  "scan_id": "kop-1744123456789",
  "score": 42,
  "grade": "D",
  "source": "root-container.yaml",
  "summary": { "critical": 2, "high": 3, "medium": 1, "low": 0, "passed": 4 },
  "findings": [
    {
      "rule": "runAsNonRoot",
      "severity": "CRITICAL",
      "category": "security",
      "message": "Container 'api' must not run as root",
      "resource": "Deployment/api-server",
      "tool": "polaris",
      "line": 18,
      "remediation": "Add securityContext.runAsNonRoot: true and runAsUser: 1000"
    }
  ]
}
```

---

## Repository Layout

```
kestrelops-demo/
├── k8s/
│   ├── good/                   # Well-configured manifests (score A)
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── networkpolicy.yaml
│   │   └── rbac.yaml
│   ├── bad/                    # Intentionally bad configs (score D/F)
│   │   ├── root-container.yaml
│   │   ├── no-limits.yaml
│   │   ├── deprecated-api.yaml
│   │   └── privileged-pod.yaml
│   └── helm/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── deployment.yaml
│           └── service.yaml
├── scripts/
│   ├── scan.sh                 # Scan any file via KestrelOps API
│   ├── scan-all.sh             # Scan every YAML in k8s/ and report
│   ├── scan-helm.sh            # helm template | KestrelOps
│   ├── scan-gke.sh             # Export GKE workloads and scan
│   ├── scan-eks.sh             # Export EKS workloads and scan
│   └── report-viewer.sh        # Open HTML report in browser
├── reports/
│   └── viewer.html             # Standalone offline report viewer
├── .github/
│   └── workflows/
│       └── kestrelops-scan.yml # CI: scan all YAMLs on push/PR
└── docs/
    ├── gke-setup.md            # Connect to GKE and scan live cluster
    ├── eks-setup.md            # Connect to EKS and scan live cluster
    └── github-app-setup.md     # Set up KestrelOps GitHub App
```

---

## Scan Results — This Repo's Own Manifests

| File | Score | Grade | Critical | High |
|---|---|---|---|---|
| `k8s/good/deployment.yaml` | 94 | A | 0 | 0 |
| `k8s/good/networkpolicy.yaml` | 98 | A+ | 0 | 0 |
| `k8s/bad/root-container.yaml` | 38 | F | 2 | 3 |
| `k8s/bad/deprecated-api.yaml` | 51 | D | 1 | 2 |
| `k8s/bad/privileged-pod.yaml` | 22 | F | 4 | 2 |
| `k8s/helm/` (rendered) | 81 | B | 0 | 1 |

---

## Docs

- [Connect to GKE →](docs/gke-setup.md)
- [Connect to EKS →](docs/eks-setup.md)
- [GitHub App Setup →](docs/github-app-setup.md)
- [KestrelOps Scanner →](https://warblecloud.com/kestrel)
- [GitHub PR Integration →](https://warblecloud.com/kestrel/github)

---

## Contact

**Warble Cloud** · [warblecloud.com](https://warblecloud.com) · [contact@warblecloud.com](mailto:contact@warblecloud.com)
