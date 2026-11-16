#!/usr/bin/env bash
# shellcheck disable=SC2016  # checks are bash expressions evaluated later by wait_until
# End-to-end check for k8s/broken/ on a disposable cluster (used by CI on kind).
#
#   1. apply every sample and wait until each reaches its documented broken state
#   2. if MCP_SERVER is set (e.g. a heron-ops binary), check that the cluster tools
#      show the evidence the READMEs promise (get_pod, get_pod_logs, list_events)
#   3. apply the fixed/ versions and wait until everything is healthy
#
# The hpa-no-requests sample needs metrics-server in the cluster.
# Usage: scripts/test-broken-workloads.sh            (current context must be local, see broken-workloads.sh)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BW="$ROOT/scripts/broken-workloads.sh"
MCP="$ROOT/scripts/mcp-call.py"
FAILS=0

pass() { echo "  ok   $*"; }
fail() { echo "  FAIL $*"; FAILS=$((FAILS + 1)); }

# wait_until <timeout-seconds> <description> <bash expression>
wait_until() {
  local timeout="$1" desc="$2" expr="$3" start=$SECONDS
  while (( SECONDS - start < timeout )); do
    if bash -c "$expr" >/dev/null 2>&1; then pass "$desc ($((SECONDS - start))s)"; return 0; fi
    sleep 3
  done
  fail "$desc (timed out after ${timeout}s)"
}

pod_of() { kubectl -n "$1" get pods -l "app=$2" -o jsonpath='{.items[0].metadata.name}'; }
# jsonpath on the first pod of app=$2 in namespace $1
pj() { kubectl -n "$1" get pods -l "app=$2" -o jsonpath="{.items[0]$3}"; }
# all event messages for an object name prefix in a namespace
ev() { kubectl -n "$1" get events -o jsonpath='{range .items[*]}{.involvedObject.name}{"\t"}{.reason}{"\t"}{.message}{"\n"}{end}' | grep "^$2" || true; }
export -f pj ev pod_of

# mcp_expect <description> <needle> <tool> <json-args>
mcp_expect() {
  [[ -n "${MCP_SERVER:-}" ]] || return 0
  local desc="$1" needle="$2" tool="$3" args="$4" out
  out="$("$MCP" "$tool" "$args" 2>&1 || true)"
  if grep -qF -- "$needle" <<<"$out"; then pass "mcp $tool: $desc"
  else fail "mcp $tool: $desc (no '$needle')"; echo "$out" | sed 's/^/        /' | head -40; fi
}

echo "== apply broken samples"
"$BW" apply all

echo "== core (namespace demo)"
wait_until 180 "broken-api restarts and exits 1 (CrashLoopBackOff)" \
  '[[ "$(pj demo broken-api "{.status.containerStatuses[0].lastState.terminated.exitCode}")" == 1 ]]'
wait_until 120 "broken-api logs contain 'db connection refused'" \
  'kubectl -n demo logs "$(pod_of demo broken-api)" | grep -q "db connection refused"'
wait_until 240 "memory-hog lastState is OOMKilled" \
  '[[ "$(pj demo memory-hog "{.status.containerStatuses[0].lastState.terminated.reason}")" == OOMKilled ]]'
if ev demo memory-hog | grep -qi oom; then fail "memory-hog has an OOM event in namespace demo (README says it does not)"; ev demo memory-hog
else pass "memory-hog namespace events mention no OOM (as documented)"; fi
wait_until 180 "bad-image waits in ErrImagePull/ImagePullBackOff" \
  '[[ "$(pj demo bad-image "{.status.containerStatuses[0].state.waiting.reason}")" =~ ^(ErrImagePull|ImagePullBackOff)$ ]]'
wait_until 60 "bad-image event names the missing tag" 'ev demo bad-image | grep -q "busybox:1.36-does-not-exist"'

echo "== missing-config"
wait_until 120 "config-api waits in CreateContainerConfigError" \
  '[[ "$(pj broken-config config-api "{.status.containerStatuses[0].state.waiting.reason}")" == CreateContainerConfigError ]]'
wait_until 60 "config-api event says configmap not found" "ev broken-config config-api | grep -q 'configmap \"app-config\" not found'"
wait_until 120 "secret-worker event says secret not found (FailedMount)" "ev broken-config secret-worker | grep FailedMount | grep -q 'secret \"db-credentials\" not found'"

echo "== unschedulable"
wait_until 60 "too-big is Unschedulable" \
  '[[ "$(pj broken-scheduling too-big "{.status.conditions[?(@.type==\"PodScheduled\")].reason}")" == Unschedulable ]]'
wait_until 60 "too-big event says Insufficient cpu" 'ev broken-scheduling too-big | grep FailedScheduling | grep -q "Insufficient cpu"'
wait_until 60 "wrong-node event says node affinity/selector" 'ev broken-scheduling wrong-node | grep FailedScheduling | grep -q "node affinity/selector"'

echo "== readiness-probe"
wait_until 120 "web is Running" '[[ "$(pj broken-readiness web "{.status.phase}")" == Running ]]'
wait_until 60 "web readiness probe fails (Unhealthy event)" 'ev broken-readiness web | grep Unhealthy | grep -q "Readiness probe failed"'
sleep 10
if [[ "$(pj broken-readiness web '{.status.containerStatuses[0].ready}')" == false ]]; then pass "web stays not ready"; else fail "web became ready"; fi
if [[ "$(pj broken-readiness web '{.status.containerStatuses[0].restartCount}')" == 0 ]]; then pass "web has 0 restarts"; else fail "web restarted"; fi

echo "== hpa-no-requests (needs metrics-server)"
wait_until 300 "HPA event says missing request for cpu" 'ev broken-hpa api | grep -q "missing request for cpu"'

if [[ -n "${MCP_SERVER:-}" ]]; then
  echo "== what the MCP cluster tools show ($MCP_SERVER)"
  p="$(pod_of demo broken-api)"
  mcp_expect "broken-api logs" "db connection refused" get_pod_logs "{\"namespace\":\"demo\",\"name\":\"$p\"}"
  p="$(pod_of demo bad-image)"
  mcp_expect "bad-image waiting reason" "ImagePull" get_pod "{\"namespace\":\"demo\",\"name\":\"$p\"}"
  mcp_expect "bad-image pull failure event" "busybox:1.36-does-not-exist" list_events '{"namespace":"demo"}'
  p="$(pod_of demo memory-hog)"
  echo "  info get_pod memory-hog (current state only; heron-ops does not render lastState):"
  { "$MCP" get_pod "{\"namespace\":\"demo\",\"name\":\"$p\"}" || true; } | sed 's/^/        /'
  mcp_expect "memory-hog restarts" "restarts=" get_pod "{\"namespace\":\"demo\",\"name\":\"$p\"}"
  p="$(pod_of broken-config config-api)"
  mcp_expect "config-api waiting reason" "CreateContainerConfigError" get_pod "{\"namespace\":\"broken-config\",\"name\":\"$p\"}"
  mcp_expect "missing configmap event" 'configmap "app-config" not found' list_events '{"namespace":"broken-config"}'
  mcp_expect "missing secret event" 'secret "db-credentials" not found' list_events '{"namespace":"broken-config"}'
  mcp_expect "configmap lookup fails" 'not found' get_configmap '{"namespace":"broken-config","name":"app-config"}'
  mcp_expect "scheduling events" "Insufficient cpu" list_events '{"namespace":"broken-scheduling"}'
  mcp_expect "scheduling events" "node affinity/selector" list_events '{"namespace":"broken-scheduling"}'
  p="$(pod_of broken-scheduling too-big)"
  mcp_expect "too-big not scheduled" "PodScheduled             False" get_pod "{\"namespace\":\"broken-scheduling\",\"name\":\"$p\"}"
  p="$(pod_of broken-readiness web)"
  mcp_expect "web not ready" "ready=false" get_pod "{\"namespace\":\"broken-readiness\",\"name\":\"$p\"}"
  mcp_expect "readiness probe event" "Readiness probe failed" list_events '{"namespace":"broken-readiness"}'
  mcp_expect "HPA listed" "Deployment/api" list_hpas '{"namespace":"broken-hpa"}'
  mcp_expect "HPA metric event" "missing request for cpu" list_events '{"namespace":"broken-hpa"}'
fi

echo "== apply fixed versions"
"$BW" fix all
for ns in demo broken-config broken-scheduling broken-readiness broken-hpa; do
  for d in $(kubectl -n "$ns" get deploy -o name); do
    if kubectl -n "$ns" rollout status "$d" --timeout=240s >/dev/null; then pass "$ns $d healthy"
    else fail "$ns $d not healthy after fix"; kubectl -n "$ns" get pods -o wide; fi
  done
done
wait_until 300 "fixed HPA reports CPU utilisation" \
  '[[ -n "$(kubectl -n broken-hpa get hpa api -o jsonpath="{.status.currentMetrics[0].resource.current.averageUtilization}")" ]]'

echo
if (( FAILS > 0 )); then
  echo "$FAILS check(s) failed"
  for ns in demo broken-config broken-scheduling broken-readiness broken-hpa; do
    echo "--- $ns"; kubectl -n "$ns" get pods,hpa -o wide || true; kubectl -n "$ns" get events --sort-by=.lastTimestamp | tail -15 || true
  done
  exit 1
fi
echo "all checks passed"
