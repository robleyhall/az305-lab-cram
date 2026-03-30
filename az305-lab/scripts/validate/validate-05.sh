#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# validate-05.sh — Validate Module 05: HA & DR
# Checks: VMs running, LB health probes, backup configured
###############################################################################

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

RG="az305-lab-ha-dr"

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
echo -e "${BLUE}  Validating Module 05: HA & DR${NC}"
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

# Virtual Machines
echo -e "${BLUE}→ Virtual Machines${NC}"
VM_LIST=$(az vm list -g "$RG" --show-details --query "[].{name:name, state:powerState, size:hardwareProfile.vmSize}" -o json 2>/dev/null || echo "[]")
VM_COUNT=$(echo "$VM_LIST" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
check "VMs exist in $RG (found: $VM_COUNT)" "$([ "$VM_COUNT" -gt 0 ] && echo true || echo false)"

if [[ "$VM_COUNT" -gt 0 ]]; then
  RUNNING_COUNT=$(echo "$VM_LIST" | python3 -c "import sys,json; print(len([v for v in json.load(sys.stdin) if v.get('state')=='VM running']))" 2>/dev/null || echo "0")
  check "VMs are running ($RUNNING_COUNT/$VM_COUNT running)" "$([ "$RUNNING_COUNT" -gt 0 ] && echo true || echo false)"

  echo "$VM_LIST" | python3 -c "
import sys, json
vms = json.load(sys.stdin)
for v in vms:
    state_icon = '▶' if v.get('state') == 'VM running' else '⏸'
    print(f\"    {state_icon} {v['name']} — {v.get('state', 'unknown')} ({v.get('size', 'N/A')})\")
" 2>/dev/null
fi

# Load Balancer
echo -e "${BLUE}→ Load Balancer${NC}"
LB_LIST=$(az network lb list -g "$RG" --query "[].{name:name, sku:sku.name}" -o json 2>/dev/null || echo "[]")
LB_COUNT=$(echo "$LB_LIST" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
check "Load Balancer exists (found: $LB_COUNT)" "$([ "$LB_COUNT" -gt 0 ] && echo true || echo false)"

if [[ "$LB_COUNT" -gt 0 ]]; then
  LB_NAME=$(echo "$LB_LIST" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['name'])" 2>/dev/null)

  # Health probes
  PROBE_COUNT=$(az network lb probe list -g "$RG" --lb-name "$LB_NAME" --query "length([])" -o tsv 2>/dev/null || echo "0")
  check "LB health probes configured (found: $PROBE_COUNT)" "$([ "$PROBE_COUNT" -gt 0 ] && echo true || echo false)"

  # Backend pools
  POOL_COUNT=$(az network lb address-pool list -g "$RG" --lb-name "$LB_NAME" --query "length([])" -o tsv 2>/dev/null || echo "0")
  check "LB backend pools configured (found: $POOL_COUNT)" "$([ "$POOL_COUNT" -gt 0 ] && echo true || echo false)"

  # LB Rules
  RULE_COUNT=$(az network lb rule list -g "$RG" --lb-name "$LB_NAME" --query "length([])" -o tsv 2>/dev/null || echo "0")
  check "LB rules configured (found: $RULE_COUNT)" "$([ "$RULE_COUNT" -gt 0 ] && echo true || echo false)"
fi

# Availability Set or Zones
echo -e "${BLUE}→ Availability${NC}"
AVSET_COUNT=$(az vm availability-set list -g "$RG" --query "length([])" -o tsv 2>/dev/null || echo "0")
if [[ "$AVSET_COUNT" -gt 0 ]]; then
  check "Availability set configured" "true"
else
  warn "No availability set found — VMs may use availability zones instead"
fi

# Backup
echo -e "${BLUE}→ Backup${NC}"
VAULT_LIST=$(az backup vault list -g "$RG" --query "[].name" -o tsv 2>/dev/null || true)
if [[ -n "$VAULT_LIST" ]]; then
  check "Recovery Services vault exists" "true"
  VAULT_NAME=$(echo "$VAULT_LIST" | head -1)
  BACKUP_ITEMS=$(az backup item list -g "$RG" -v "$VAULT_NAME" --query "length([])" -o tsv 2>/dev/null || echo "0")
  check "Backup items configured (found: $BACKUP_ITEMS)" "$([ "$BACKUP_ITEMS" -gt 0 ] && echo true || echo false)"
else
  warn "No Recovery Services vault found — backup may not be configured"
fi

# Summary
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "  Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}, ${YELLOW}${WARN} warnings${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

[[ $FAIL -gt 0 ]] && exit 1
exit 0
