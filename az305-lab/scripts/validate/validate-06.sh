#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# validate-06.sh — Validate Module 06: Storage
# Checks: Storage accounts, lifecycle rules, blob containers
###############################################################################

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

RG="az305-lab-storage"

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
echo -e "${BLUE}  Validating Module 06: Storage${NC}"
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

# Storage Accounts
echo -e "${BLUE}→ Storage Accounts${NC}"
SA_LIST=$(az storage account list -g "$RG" --query "[].{name:name, sku:sku.name, kind:kind, access:allowBlobPublicAccess}" -o json 2>/dev/null || echo "[]")
SA_COUNT=$(echo "$SA_LIST" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
check "Storage accounts exist (found: $SA_COUNT)" "$([ "$SA_COUNT" -gt 0 ] && echo true || echo false)"

if [[ "$SA_COUNT" -gt 0 ]]; then
  echo "$SA_LIST" | python3 -c "
import sys, json
accounts = json.load(sys.stdin)
for a in accounts:
    pub = 'public' if a.get('access') else 'private'
    print(f\"    • {a['name']} ({a['sku']}, {a['kind']}, {pub})\")
" 2>/dev/null

  # Check each storage account
  echo "$SA_LIST" | python3 -c "
import sys, json
accounts = json.load(sys.stdin)
for a in accounts:
    print(a['name'])
" 2>/dev/null | while read -r sa_name; do

    # Blob containers
    echo -e "${BLUE}→ Blob Containers ($sa_name)${NC}"
    CONN_STR=$(az storage account show-connection-string -g "$RG" -n "$sa_name" --query "connectionString" -o tsv 2>/dev/null || echo "")
    if [[ -n "$CONN_STR" ]]; then
      CONTAINER_COUNT=$(az storage container list --connection-string "$CONN_STR" --query "length([])" -o tsv 2>/dev/null || echo "0")
      check "Blob containers exist in $sa_name (found: $CONTAINER_COUNT)" "$([ "$CONTAINER_COUNT" -gt 0 ] && echo true || echo false)"

      if [[ "$CONTAINER_COUNT" -gt 0 ]]; then
        az storage container list --connection-string "$CONN_STR" --query "[].name" -o tsv 2>/dev/null | while read -r cname; do
          echo -e "      • $cname"
        done
      fi
    else
      warn "Could not get connection string for $sa_name"
    fi

    # Lifecycle management
    echo -e "${BLUE}→ Lifecycle Rules ($sa_name)${NC}"
    LIFECYCLE=$(az storage account management-policy show -g "$RG" -n "$sa_name" --query "policy.rules" -o json 2>/dev/null || echo "null")
    if [[ "$LIFECYCLE" != "null" && "$LIFECYCLE" != "[]" ]]; then
      RULE_COUNT=$(echo "$LIFECYCLE" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
      check "Lifecycle rules configured for $sa_name (found: $RULE_COUNT)" "true"
    else
      warn "No lifecycle rules on $sa_name (may be by design)"
    fi
  done
fi

# Summary
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "  Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}, ${YELLOW}${WARN} warnings${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

[[ $FAIL -gt 0 ]] && exit 1
exit 0
