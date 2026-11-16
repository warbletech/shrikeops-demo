#!/usr/bin/env bash
# Apply, fix, inspect or remove the evaluator broken-workload samples in k8s/broken/.
#
#   scripts/broken-workloads.sh apply   [all|core|<scenario>...]   # default: all
#   scripts/broken-workloads.sh fix     [all|core|<scenario>...]   # apply the fixed/ versions
#   scripts/broken-workloads.sh status
#   scripts/broken-workloads.sh cleanup                            # delete every sample namespace
#
# "core" is the quickstart set in namespace demo (crash loop, OOM kill, bad image tag).
# Scenarios live in k8s/broken/scenarios/<name>/ and each uses its own namespace.
#
# Safety: refuses to run unless the current kubectl context looks like a local, disposable
# cluster (kind-*, minikube, k3d-*, docker-desktop, rancher-desktop, colima, orbstack).
# Set ALLOW_ANY_CONTEXT=1 to override; only do that for a throwaway cluster.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BROKEN="$ROOT/k8s/broken"
SCENARIOS=(missing-config unschedulable readiness-probe hpa-no-requests)
NAMESPACES=(demo broken-config broken-scheduling broken-readiness broken-hpa)

die() { echo "error: $*" >&2; exit 1; }

check_context() {
  command -v kubectl >/dev/null || die "kubectl not found"
  local ctx
  ctx="$(kubectl config current-context 2>/dev/null)" || die "no current kubectl context"
  if [[ "${ALLOW_ANY_CONTEXT:-0}" != 1 ]] &&
     ! [[ "$ctx" =~ ^(kind-.*|minikube|k3d-.*|docker-desktop|rancher-desktop|colima.*|orbstack)$ ]]; then
    die "current context '$ctx' does not look like a local disposable cluster; set ALLOW_ANY_CONTEXT=1 to override"
  fi
  echo "context: $ctx"
}

targets() { # expand all|core|<scenario> into a list of targets
  if [[ $# -eq 0 || "$1" == all ]]; then echo core "${SCENARIOS[@]}"; return; fi
  local t
  for t in "$@"; do
    if [[ "$t" == core ]] || [[ " ${SCENARIOS[*]} " == *" $t "* ]]; then echo "$t"
    else die "unknown sample '$t' (expected all, core, or one of: ${SCENARIOS[*]})"; fi
  done
}

apply_target() { # $1 target, $2 broken|fixed
  local t="$1" v="$2"
  if [[ "$t" == core ]]; then
    kubectl apply -f "$BROKEN/namespace.yaml"
    if [[ "$v" == broken ]]; then kubectl apply -f "$BROKEN/"; else kubectl apply -f "$BROKEN/fixed/"; fi
  else
    kubectl apply -f "$BROKEN/scenarios/$t/$v.yaml"
  fi
}

cmd="${1:-}"; shift || true
case "$cmd" in
  apply|fix)
    check_context
    v=broken; [[ "$cmd" == fix ]] && v=fixed
    list="$(targets "$@")"
    for t in $list; do echo "== $cmd $t"; apply_target "$t" "$v"; done
    if [[ "$cmd" == apply ]]; then echo "Failures show up within ~1-2 minutes. Run: $0 status"; fi
    ;;
  status)
    check_context
    for ns in "${NAMESPACES[@]}"; do
      kubectl get namespace "$ns" >/dev/null 2>&1 || continue
      echo "== namespace $ns"
      kubectl -n "$ns" get pods,hpa -o wide 2>/dev/null || true
    done
    ;;
  cleanup)
    check_context
    kubectl delete namespace "${NAMESPACES[@]}" --ignore-not-found --wait=false
    ;;
  *)
    sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    if ! [[ -z "$cmd" || "$cmd" == -h || "$cmd" == --help || "$cmd" == help ]]; then exit 2; fi
    ;;
esac
