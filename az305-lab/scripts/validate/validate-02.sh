#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# validate-02.sh — Validate Module 02: Identity
# Checks: AD groups, app registration
###############################################################################

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

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
echo -e "${BLUE}  Validating Module 02: Identity${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# AD Groups
echo -e "${BLUE}→ Entra ID Groups${NC}"
AD_GROUPS=$(az ad group list --query "[?contains(displayName, 'az305-lab') || contains(displayName, 'CertLab')].{name:displayName, id:id}" -o json 2>/dev/null || echo "[]")
GROUP_COUNT=$(echo "$AD_GROUPS" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
check "Lab AD groups exist (found: $GROUP_COUNT)" "$([ "$GROUP_COUNT" -gt 0 ] && echo true || echo false)"

if [[ "$GROUP_COUNT" -gt 0 ]]; then
  echo "$AD_GROUPS" | python3 -c "
import sys, json
groups = json.load(sys.stdin)
for g in groups:
    print(f\"    • {g['name']}\")
" 2>/dev/null
fi

# App Registration
echo -e "${BLUE}→ App Registrations${NC}"
APP_REGS=$(az ad app list --query "[?contains(displayName, 'az305-lab') || contains(displayName, 'CertLab')].{name:displayName, appId:appId}" -o json 2>/dev/null || echo "[]")
APP_COUNT=$(echo "$APP_REGS" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
check "Lab app registration exists (found: $APP_COUNT)" "$([ "$APP_COUNT" -gt 0 ] && echo true || echo false)"

if [[ "$APP_COUNT" -gt 0 ]]; then
  echo "$APP_REGS" | python3 -c "
import sys, json
apps = json.load(sys.stdin)
for a in apps:
    print(f\"    • {a['name']} (appId: {a['appId'][:8]}...)\")
" 2>/dev/null
fi

# Service Principals
echo -e "${BLUE}→ Service Principals${NC}"
SPN_COUNT=$(az ad sp list --query "[?contains(displayName, 'az305-lab') || contains(displayName, 'CertLab')].displayName" -o json 2>/dev/null | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
check "Lab service principals exist (found: $SPN_COUNT)" "$([ "$SPN_COUNT" -gt 0 ] && echo true || echo false)"

# Managed Identities
echo -e "${BLUE}→ Managed Identities${NC}"
RG="az305-lab-identity"
RG_EXISTS=$(az group exists --name "$RG" 2>/dev/null || echo "false")
if [[ "$RG_EXISTS" == "true" ]]; then
  MI_COUNT=$(az identity list -g "$RG" --query "length([])" -o tsv 2>/dev/null || echo "0")
  check "Managed identities exist in $RG (found: $MI_COUNT)" "$([ "$MI_COUNT" -gt 0 ] && echo true || echo false)"
else
  warn "Resource group $RG not found — skipping managed identity check"
fi

# Summary
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "  Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}, ${YELLOW}${WARN} warnings${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

[[ $FAIL -gt 0 ]] && exit 1
exit 0
