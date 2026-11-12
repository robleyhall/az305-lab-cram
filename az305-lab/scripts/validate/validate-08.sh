#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# validate-08.sh — Validate Module 08: Data Integration
# Checks: Data Factory, Data Lake containers
###############################################################################

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

RG="az305-lab-data-integration"

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
echo -e "${BLUE}  Validating Module 08: Data Integration${NC}"
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

# Data Factory
echo -e "${BLUE}→ Data Factory${NC}"
ADF_LIST=$(az datafactory list -g "$RG" --query "[].{name:name, state:provisioningState}" -o json 2>/dev/null || echo "[]")
ADF_COUNT=$(echo "$ADF_LIST" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
check "Data Factory exists (found: $ADF_COUNT)" "$([ "$ADF_COUNT" -gt 0 ] && echo true || echo false)"

if [[ "$ADF_COUNT" -gt 0 ]]; then
  ADF_NAME=$(echo "$ADF_LIST" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['name'])" 2>/dev/null)
  ADF_STATE=$(echo "$ADF_LIST" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['state'])" 2>/dev/null)
  check "Data Factory provisioned (state: $ADF_STATE)" "$([ "$ADF_STATE" == "Succeeded" ] && echo true || echo false)"
  echo -e "  ${BLUE}  Data Factory: $ADF_NAME${NC}"

  # Check pipelines
  PIPELINE_COUNT=$(az datafactory pipeline list --factory-name "$ADF_NAME" -g "$RG" --query "length([])" -o tsv 2>/dev/null || echo "0")
  if [[ "$PIPELINE_COUNT" -gt 0 ]]; then
    check "ADF pipelines configured (found: $PIPELINE_COUNT)" "true"
  else
    warn "No ADF pipelines found (may need manual configuration)"
  fi

  # Check linked services
  LS_COUNT=$(az datafactory linked-service list --factory-name "$ADF_NAME" -g "$RG" --query "length([])" -o tsv 2>/dev/null || echo "0")
  if [[ "$LS_COUNT" -gt 0 ]]; then
    check "ADF linked services configured (found: $LS_COUNT)" "true"
  else
    warn "No ADF linked services found"
  fi
fi

# Data Lake (ADLS Gen2 storage accounts)
echo -e "${BLUE}→ Data Lake Storage${NC}"
ADLS_LIST=$(az storage account list -g "$RG" --query "[?isHnsEnabled].{name:name, sku:sku.name}" -o json 2>/dev/null || echo "[]")
ADLS_COUNT=$(echo "$ADLS_LIST" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

if [[ "$ADLS_COUNT" -eq 0 ]]; then
  # Fall back: check all storage accounts in the RG
  ADLS_LIST=$(az storage account list -g "$RG" --query "[].{name:name, sku:sku.name}" -o json 2>/dev/null || echo "[]")
  ADLS_COUNT=$(echo "$ADLS_LIST" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
fi

check "Data Lake / Storage account exists (found: $ADLS_COUNT)" "$([ "$ADLS_COUNT" -gt 0 ] && echo true || echo false)"

if [[ "$ADLS_COUNT" -gt 0 ]]; then
  DL_NAME=$(echo "$ADLS_LIST" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['name'])" 2>/dev/null)

  # Check containers / filesystems
  CONN_STR=$(az storage account show-connection-string -g "$RG" -n "$DL_NAME" --query "connectionString" -o tsv 2>/dev/null || echo "")
  if [[ -n "$CONN_STR" ]]; then
    CONTAINER_COUNT=$(az storage container list --connection-string "$CONN_STR" --query "length([])" -o tsv 2>/dev/null || echo "0")
    check "Data Lake containers exist (found: $CONTAINER_COUNT)" "$([ "$CONTAINER_COUNT" -gt 0 ] && echo true || echo false)"

    if [[ "$CONTAINER_COUNT" -gt 0 ]]; then
      az storage container list --connection-string "$CONN_STR" --query "[].name" -o tsv 2>/dev/null | while read -r cname; do
        echo -e "      • $cname"
      done
    fi
  else
    warn "Could not get connection string for $DL_NAME"
  fi
fi

# Summary
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "  Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}, ${YELLOW}${WARN} warnings${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

[[ $FAIL -gt 0 ]] && exit 1
exit 0
