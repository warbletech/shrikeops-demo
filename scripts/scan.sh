#!/usr/bin/env bash
# scan.sh — Scan a single YAML file via KestrelOps API
# Usage: ./scripts/scan.sh <path/to/manifest.yaml> [--json]
#
# Options:
#   --json     Print full JSON response instead of formatted output
#
# Prerequisites: curl, jq
# KestrelOps API: https://warblecloud.com/kestrel (free: 3 scans/day)

set -euo pipefail

KESTREL_API="${KESTREL_API:-https://warblecloud.com/api/kestrel-scan}"
FILE="${1:-}"
JSON_MODE=false
[[ "${2:-}" == "--json" ]] && JSON_MODE=true

if [[ -z "$FILE" ]]; then
  echo "Usage: $0 <manifest.yaml> [--json]"
  exit 1
fi

if [[ ! -f "$FILE" ]]; then
  echo "Error: file not found: $FILE"
  exit 1
fi

echo "🦅 KestrelOps — scanning: $FILE"
echo "   API: $KESTREL_API"
echo ""

MANIFEST=$(cat "$FILE")
RESPONSE=$(curl -sf -X POST "$KESTREL_API" \
  -H "Content-Type: application/json" \
  -d "{\"manifest\": $(echo "$MANIFEST" | jq -Rs .), \"source\": \"$FILE\"}" \
  --max-time 30)

if [[ "$JSON_MODE" == "true" ]]; then
  echo "$RESPONSE" | jq .
  exit 0
fi

# Pretty-print results
SCORE=$(echo "$RESPONSE" | jq -r '.score')
GRADE=$(echo "$RESPONSE" | jq -r '.grade')
CRIT=$(echo "$RESPONSE"  | jq -r '.summary.critical')
HIGH=$(echo "$RESPONSE"  | jq -r '.summary.high')
MED=$(echo "$RESPONSE"   | jq -r '.summary.medium')
LOW=$(echo "$RESPONSE"   | jq -r '.summary.low')
PASS=$(echo "$RESPONSE"  | jq -r '.summary.passed')
SCAN_ID=$(echo "$RESPONSE" | jq -r '.scan_id')

echo "╔══════════════════════════════════════════════╗"
printf "║  Score: %-3s  Grade: %-2s  Scan: %-16s ║\n" "$SCORE" "$GRADE" "$SCAN_ID"
echo "╠══════════════════════════════════════════════╣"
printf "║  🔴 Critical: %-3s  🟠 High: %-3s              ║\n" "$CRIT" "$HIGH"
printf "║  🟡 Medium:   %-3s  🟢 Low:  %-3s  ✅ Pass: %-3s ║\n" "$MED" "$LOW" "$PASS"
echo "╚══════════════════════════════════════════════╝"
echo ""

if [[ "$CRIT" -gt 0 || "$HIGH" -gt 0 ]]; then
  echo "Findings:"
  echo "$RESPONSE" | jq -r '
    .findings[]
    | select(.severity == "CRITICAL" or .severity == "HIGH")
    | "  [\(.severity | if . == "CRITICAL" then "🔴" else "🟠" end) \(.severity)] \(.rule)\n    → \(.message)\n    → Fix: \(.remediation // "See KestrelOps docs")\n"
  '
fi

if [[ "$CRIT" -gt 0 ]]; then
  echo "❌ FAILED — critical findings must be resolved before deployment"
  exit 2
elif [[ "$SCORE" -lt 60 ]]; then
  echo "⚠️  WARNING — score below 60, review high findings"
  exit 1
else
  echo "✅ PASSED — score: $SCORE"
fi
