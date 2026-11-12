#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# validate-04.sh — Validate Module 04: Monitoring
# Checks: App Insights collecting, alerts configured, action group exists
###############################################################################

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

RG="az305-lab-monitoring"

check() {
  local description="$1"
  local result="$2"
  if [[ "$result" == "true" || "$result" == "0" ]]; then
    echo -e "  ${GREEN}✓ PASS${NC} — $description"
    ((PASS++))
  else
    echo -e "  ${RED}✗ FAIL${NC} — $description"
    ((FAIL++))
  fi
}

warn() {
  local description="$1"
  echo -e "  ${YELLOW}⚠ WARN${NC} — $description"
  ((WARN++))
}

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Validating Module 04: Monitoring${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Resource group
echo -e "${BLUE}→ Resource Group${NC}"
RG_EXISTS=$(az group exists --name "$RG" 2>/dev/null || echo "false")
check "Resource group '$RG' exists" "$RG_EXISTS"

if [[ "$RG_EXISTS" != "true" ]]; then
  echo -e "${RED}Resource group not found. Cannot continue validation.${NC}"
  echo -e "${RED}Results: ${PASS} passed, ${FAIL} failed, ${WARN} warnings${NC}"
  exit 1
fi

# Application Insights
echo -e "${BLUE}→ Application Insights${NC}"
AI_LIST=$(az monitor app-insights component show -g "$RG" --query "[].{name:name, state:provisioningState, kind:kind}" -o json 2>/dev/null || echo "[]")
AI_COUNT=$(echo "$AI_LIST" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
check "Application Insights exists (found: $AI_COUNT)" "$([ "$AI_COUNT" -gt 0 ] && echo true || echo false)"

if [[ "$AI_COUNT" -gt 0 ]]; then
  AI_NAME=$(echo "$AI_LIST" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['name'])" 2>/dev/null)
  echo -e "  ${BLUE}  App Insights: $AI_NAME${NC}"

  # Check if collecting data
  AI_KEY=$(az monitor app-insights component show -g "$RG" --app "$AI_NAME" --query "connectionString" -o tsv 2>/dev/null || echo "none")
  check "Application Insights has connection string" "$([ "$AI_KEY" != "none" ] && [ -n "$AI_KEY" ] && echo true || echo false)"
fi

# Action Groups
echo -e "${BLUE}→ Action Groups${NC}"
AG_LIST=$(az monitor action-group list -g "$RG" --query "[].{name:name, enabled:enabled}" -o json 2>/dev/null || echo "[]")
AG_COUNT=$(echo "$AG_LIST" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
check "Action groups exist (found: $AG_COUNT)" "$([ "$AG_COUNT" -gt 0 ] && echo true || echo false)"

if [[ "$AG_COUNT" -gt 0 ]]; then
  echo "$AG_LIST" | python3 -c "
import sys, json
groups = json.load(sys.stdin)
for g in groups:
    status = 'enabled' if g.get('enabled', False) else 'disabled'
    print(f\"    • {g['name']} ({status})\")
" 2>/dev/null
fi

# Metric Alerts
echo -e "${BLUE}→ Metric Alerts${NC}"
ALERT_COUNT=$(az monitor metrics alert list -g "$RG" --query "length([])" -o tsv 2>/dev/null || echo "0")
check "Metric alerts configured (found: $ALERT_COUNT)" "$([ "$ALERT_COUNT" -gt 0 ] && echo true || echo false)"

if [[ "$ALERT_COUNT" -gt 0 ]]; then
  az monitor metrics alert list -g "$RG" --query "[].{name:name, enabled:enabled, severity:severity}" -o table 2>/dev/null || true
fi

# Activity Log Alerts
echo -e "${BLUE}→ Activity Log Alerts${NC}"
ACT_ALERT_COUNT=$(az monitor activity-log alert list -g "$RG" --query "length([])" -o tsv 2>/dev/null || echo "0")
if [[ "$ACT_ALERT_COUNT" -gt 0 ]]; then
  check "Activity log alerts configured (found: $ACT_ALERT_COUNT)" "true"
else
  warn "No activity log alerts found (may be by design)"
fi

# Summary
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "  Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}, ${YELLOW}${WARN} warnings${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

[[ $FAIL -gt 0 ]] && exit 1
exit 0
