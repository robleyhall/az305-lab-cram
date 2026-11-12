#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# validate-03.sh — Validate Module 03: Key Vault
# Checks: Key Vault accessible, secret/key/cert exist, private endpoint
###############################################################################

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

RG="az305-lab-keyvault"

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
echo -e "${BLUE}  Validating Module 03: Key Vault${NC}"
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

# Key Vault
echo -e "${BLUE}→ Key Vault${NC}"
KV_LIST=$(az keyvault list -g "$RG" --query "[].{name:name, state:properties.provisioningState}" -o json 2>/dev/null || echo "[]")
KV_COUNT=$(echo "$KV_LIST" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
check "Key Vault exists in $RG (found: $KV_COUNT)" "$([ "$KV_COUNT" -gt 0 ] && echo true || echo false)"

if [[ "$KV_COUNT" -gt 0 ]]; then
  KV_NAME=$(echo "$KV_LIST" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['name'])" 2>/dev/null)
  echo -e "  ${BLUE}  Key Vault: $KV_NAME${NC}"

  # Check accessibility
  echo -e "${BLUE}→ Key Vault Accessibility${NC}"
  KV_SHOW=$(az keyvault show --name "$KV_NAME" --query "properties.provisioningState" -o tsv 2>/dev/null || echo "failed")
  check "Key Vault is accessible (state: $KV_SHOW)" "$([ "$KV_SHOW" == "Succeeded" ] && echo true || echo false)"

  # Check secrets
  echo -e "${BLUE}→ Secrets${NC}"
  SECRET_COUNT=$(az keyvault secret list --vault-name "$KV_NAME" --query "length([])" -o tsv 2>/dev/null || echo "0")
  check "Secrets exist in vault (found: $SECRET_COUNT)" "$([ "$SECRET_COUNT" -gt 0 ] && echo true || echo false)"

  if [[ "$SECRET_COUNT" -gt 0 ]]; then
    az keyvault secret list --vault-name "$KV_NAME" --query "[].name" -o tsv 2>/dev/null | while read -r name; do
      echo -e "    • $name"
    done
  fi

  # Check keys
  echo -e "${BLUE}→ Keys${NC}"
  KEY_COUNT=$(az keyvault key list --vault-name "$KV_NAME" --query "length([])" -o tsv 2>/dev/null || echo "0")
  check "Keys exist in vault (found: $KEY_COUNT)" "$([ "$KEY_COUNT" -gt 0 ] && echo true || echo false)"

  # Check certificates
  echo -e "${BLUE}→ Certificates${NC}"
  CERT_COUNT=$(az keyvault certificate list --vault-name "$KV_NAME" --query "length([])" -o tsv 2>/dev/null || echo "0")
  check "Certificates exist in vault (found: $CERT_COUNT)" "$([ "$CERT_COUNT" -gt 0 ] && echo true || echo false)"

  # Check private endpoint
  echo -e "${BLUE}→ Private Endpoint${NC}"
  PE_COUNT=$(az network private-endpoint list -g "$RG" --query "length([?contains(name, 'kv') || contains(name, 'keyvault')])" -o tsv 2>/dev/null || echo "0")
  if [[ "$PE_COUNT" -gt 0 ]]; then
    check "Private endpoint exists for Key Vault" "true"

    # Check DNS resolution
    KV_FQDN="${KV_NAME}.vault.azure.net"
    DNS_RESULT=$(nslookup "$KV_FQDN" 2>/dev/null | grep -c "privatelink" || echo "0")
    if [[ "$DNS_RESULT" -gt 0 ]]; then
      check "Private endpoint DNS resolves via privatelink" "true"
    else
      warn "Private endpoint DNS may not resolve via privatelink from this network"
    fi
  else
    warn "No private endpoint found for Key Vault (may be by design)"
  fi
fi

# Summary
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "  Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}, ${YELLOW}${WARN} warnings${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

[[ $FAIL -gt 0 ]] && exit 1
exit 0
