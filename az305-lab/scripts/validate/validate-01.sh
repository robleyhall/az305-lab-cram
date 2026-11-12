#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# validate-01.sh — Validate Module 01: Governance
# Checks: Policy assignments, custom role definitions
###############################################################################

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

RG="az305-lab-governance"

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
echo -e "${BLUE}  Validating Module 01: Governance${NC}"
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

# Policy assignments
echo -e "${BLUE}→ Policy Assignments${NC}"
SUB_ID=$(az account show --query "id" -o tsv 2>/dev/null)

POLICY_ASSIGNMENTS=$(az policy assignment list --query "[?contains(displayName, 'az305-lab') || contains(name, 'az305-lab')].{name:name, state:enforcementMode}" -o json 2>/dev/null || echo "[]")
POLICY_COUNT=$(echo "$POLICY_ASSIGNMENTS" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
check "Lab policy assignments exist (found: $POLICY_COUNT)" "$([ "$POLICY_COUNT" -gt 0 ] && echo true || echo false)"

if [[ "$POLICY_COUNT" -gt 0 ]]; then
  echo "$POLICY_ASSIGNMENTS" | python3 -c "
import sys, json
items = json.load(sys.stdin)
for i in items:
    print(f\"    • {i['name']} (enforcement: {i.get('state', 'default')})\")
" 2>/dev/null
fi

# Custom role definitions
echo -e "${BLUE}→ Custom Role Definitions${NC}"
CUSTOM_ROLES=$(az role definition list --custom-role-only true --query "[?contains(roleName, 'az305-lab') || contains(roleName, 'CertLab') || contains(roleName, 'Lab')].roleName" -o json 2>/dev/null || echo "[]")
ROLE_COUNT=$(echo "$CUSTOM_ROLES" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
check "Custom role definition exists (found: $ROLE_COUNT)" "$([ "$ROLE_COUNT" -gt 0 ] && echo true || echo false)"

if [[ "$ROLE_COUNT" -gt 0 ]]; then
  echo "$CUSTOM_ROLES" | python3 -c "
import sys, json
roles = json.load(sys.stdin)
for r in roles:
    print(f\"    • {r}\")
" 2>/dev/null
fi

# Resource tags
echo -e "${BLUE}→ Resource Tagging${NC}"
TAGGED_COUNT=$(az resource list -g "$RG" --query "length([?tags.Lab=='AZ-305'])" -o tsv 2>/dev/null || echo "0")
TOTAL_COUNT=$(az resource list -g "$RG" --query "length([])" -o tsv 2>/dev/null || echo "0")
check "Resources are tagged (${TAGGED_COUNT}/${TOTAL_COUNT} tagged)" "$([ "$TAGGED_COUNT" -gt 0 ] && echo true || echo false)"

# Summary
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "  Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}, ${YELLOW}${WARN} warnings${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

[[ $FAIL -gt 0 ]] && exit 1
exit 0
