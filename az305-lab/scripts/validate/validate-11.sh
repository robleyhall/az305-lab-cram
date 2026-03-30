#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# validate-11.sh — Validate Module 11: Networking
# Checks: VNet peering, NSG rules, DNS zone
###############################################################################

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

RG="az305-lab-networking"

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
echo -e "${BLUE}  Validating Module 11: Networking${NC}"
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

# VNets
echo -e "${BLUE}→ Virtual Networks${NC}"
VNET_LIST=$(az network vnet list -g "$RG" --query "[].{name:name, space:addressSpace.addressPrefixes[0]}" -o json 2>/dev/null || echo "[]")
VNET_COUNT=$(echo "$VNET_LIST" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
check "VNets exist (found: $VNET_COUNT)" "$([ "$VNET_COUNT" -gt 0 ] && echo true || echo false)"

if [[ "$VNET_COUNT" -gt 0 ]]; then
  echo "$VNET_LIST" | python3 -c "
import sys, json
for v in json.load(sys.stdin):
    print(f\"    • {v['name']} ({v.get('space', 'N/A')})\")
" 2>/dev/null

  # VNet Peering
  echo -e "${BLUE}→ VNet Peering${NC}"
  PEERING_FOUND=false

  echo "$VNET_LIST" | python3 -c "
import sys, json
for v in json.load(sys.stdin):
    print(v['name'])
" 2>/dev/null | while read -r vnet_name; do
    PEERING_LIST=$(az network vnet peering list -g "$RG" --vnet-name "$vnet_name" --query "[].{name:name, state:peeringState, remote:remoteVirtualNetwork.id}" -o json 2>/dev/null || echo "[]")
    PEER_COUNT=$(echo "$PEERING_LIST" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

    if [[ "$PEER_COUNT" -gt 0 ]]; then
      echo -e "  ${GREEN}✓ PASS${NC} — VNet peering configured on $vnet_name (found: $PEER_COUNT)"
      echo "$PEERING_LIST" | python3 -c "
import sys, json
for p in json.load(sys.stdin):
    remote = p.get('remote', '').split('/')[-1] if p.get('remote') else 'unknown'
    print(f\"      → {p['name']} (state: {p.get('state', 'unknown')}, remote: {remote})\")
" 2>/dev/null
    fi
  done
fi

# NSGs
echo -e "${BLUE}→ Network Security Groups${NC}"
NSG_LIST=$(az network nsg list -g "$RG" --query "[].{name:name, rules:securityRules | length(@)}" -o json 2>/dev/null || echo "[]")
NSG_COUNT=$(echo "$NSG_LIST" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
check "NSGs exist (found: $NSG_COUNT)" "$([ "$NSG_COUNT" -gt 0 ] && echo true || echo false)"

if [[ "$NSG_COUNT" -gt 0 ]]; then
  echo "$NSG_LIST" | python3 -c "
import sys, json
for n in json.load(sys.stdin):
    print(f\"    • {n['name']} ({n.get('rules', 0)} custom rules)\")
" 2>/dev/null

  # Check NSG rules are applied
  NSG_NAME=$(echo "$NSG_LIST" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['name'])" 2>/dev/null)
  RULE_COUNT=$(az network nsg rule list -g "$RG" --nsg-name "$NSG_NAME" --query "length([])" -o tsv 2>/dev/null || echo "0")
  check "NSG rules applied on $NSG_NAME (found: $RULE_COUNT)" "$([ "$RULE_COUNT" -gt 0 ] && echo true || echo false)"

  if [[ "$RULE_COUNT" -gt 0 ]]; then
    az network nsg rule list -g "$RG" --nsg-name "$NSG_NAME" --query "[].{name:name, access:access, direction:direction, port:destinationPortRange, priority:priority}" -o table 2>/dev/null || true
  fi
fi

# DNS Zones
echo -e "${BLUE}→ DNS Zones${NC}"
DNS_LIST=$(az network dns zone list -g "$RG" --query "[].{name:name, records:numberOfRecordSets}" -o json 2>/dev/null || echo "[]")
DNS_COUNT=$(echo "$DNS_LIST" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

if [[ "$DNS_COUNT" -gt 0 ]]; then
  check "DNS zones exist (found: $DNS_COUNT)" "true"
  echo "$DNS_LIST" | python3 -c "
import sys, json
for d in json.load(sys.stdin):
    print(f\"    • {d['name']} ({d.get('records', 0)} record sets)\")
" 2>/dev/null

  DNS_NAME=$(echo "$DNS_LIST" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['name'])" 2>/dev/null)
  RESOLVE_RESULT=$(nslookup "$DNS_NAME" 2>/dev/null && echo "ok" || echo "fail")
  if [[ "$RESOLVE_RESULT" == *"ok"* ]]; then
    check "DNS zone resolving ($DNS_NAME)" "true"
  else
    warn "DNS zone may not resolve from this network (delegation may be needed)"
  fi
else
  # Check private DNS zones
  PDNS_LIST=$(az network private-dns zone list -g "$RG" --query "[].name" -o json 2>/dev/null || echo "[]")
  PDNS_COUNT=$(echo "$PDNS_LIST" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
  if [[ "$PDNS_COUNT" -gt 0 ]]; then
    check "Private DNS zones exist (found: $PDNS_COUNT)" "true"
  else
    warn "No DNS zones (public or private) found in $RG"
  fi
fi

# Summary
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "  Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}, ${YELLOW}${WARN} warnings${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

[[ $FAIL -gt 0 ]] && exit 1
exit 0
