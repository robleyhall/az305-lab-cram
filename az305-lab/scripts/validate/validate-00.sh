#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# validate-00.sh — Validate Module 00: Foundation
# Checks: VNet, subnets, Log Analytics workspace
###############################################################################

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

RG="az305-lab-foundation"

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
echo -e "${BLUE}  Validating Module 00: Foundation${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Check resource group exists
echo -e "${BLUE}→ Resource Group${NC}"
RG_EXISTS=$(az group exists --name "$RG" 2>/dev/null || echo "false")
check "Resource group '$RG' exists" "$RG_EXISTS"

if [[ "$RG_EXISTS" != "true" ]]; then
  echo -e "${RED}Resource group not found. Cannot continue validation.${NC}"
  echo -e "${RED}Results: ${PASS} passed, ${FAIL} failed, ${WARN} warnings${NC}"
  exit 1
fi

# Check VNet
echo -e "${BLUE}→ Virtual Network${NC}"
VNET_COUNT=$(az network vnet list -g "$RG" --query "length([])" -o tsv 2>/dev/null || echo "0")
check "VNet exists in $RG" "$([ "$VNET_COUNT" -gt 0 ] && echo true || echo false)"

if [[ "$VNET_COUNT" -gt 0 ]]; then
  VNET_NAME=$(az network vnet list -g "$RG" --query "[0].name" -o tsv 2>/dev/null)

  # Check subnets
  echo -e "${BLUE}→ Subnets${NC}"
  SUBNET_COUNT=$(az network vnet subnet list -g "$RG" --vnet-name "$VNET_NAME" --query "length([])" -o tsv 2>/dev/null || echo "0")
  check "VNet has subnets configured" "$([ "$SUBNET_COUNT" -gt 0 ] && echo true || echo false)"

  SUBNET_NAMES=$(az network vnet subnet list -g "$RG" --vnet-name "$VNET_NAME" --query "[].name" -o tsv 2>/dev/null || true)
  if [[ -n "$SUBNET_NAMES" ]]; then
    echo -e "  ${BLUE}  Subnets found:${NC}"
    echo "$SUBNET_NAMES" | while read -r sn; do
      echo -e "  ${BLUE}    • $sn${NC}"
    done
  fi

  # Check VNet address space
  ADDR_SPACE=$(az network vnet show -g "$RG" -n "$VNET_NAME" --query "addressSpace.addressPrefixes[0]" -o tsv 2>/dev/null || echo "none")
  check "VNet has address space configured ($ADDR_SPACE)" "$([ "$ADDR_SPACE" != "none" ] && echo true || echo false)"
fi

# Check Log Analytics Workspace
echo -e "${BLUE}→ Log Analytics Workspace${NC}"
LAW_COUNT=$(az monitor log-analytics workspace list -g "$RG" --query "length([])" -o tsv 2>/dev/null || echo "0")
check "Log Analytics workspace exists" "$([ "$LAW_COUNT" -gt 0 ] && echo true || echo false)"

if [[ "$LAW_COUNT" -gt 0 ]]; then
  LAW_STATE=$(az monitor log-analytics workspace list -g "$RG" --query "[0].provisioningState" -o tsv 2>/dev/null || echo "unknown")
  check "Log Analytics workspace is active (state: $LAW_STATE)" "$([ "$LAW_STATE" == "Succeeded" ] && echo true || echo false)"

  LAW_SKU=$(az monitor log-analytics workspace list -g "$RG" --query "[0].sku.name" -o tsv 2>/dev/null || echo "unknown")
  echo -e "  ${BLUE}  SKU: $LAW_SKU${NC}"
fi

# Summary
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "  Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}, ${YELLOW}${WARN} warnings${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

[[ $FAIL -gt 0 ]] && exit 1
exit 0
