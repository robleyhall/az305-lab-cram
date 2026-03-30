#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# validate-07.sh — Validate Module 07: Databases
# Checks: SQL Server accessible, databases online, CosmosDB responding
###############################################################################

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

RG="az305-lab-databases"

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
echo -e "${BLUE}  Validating Module 07: Databases${NC}"
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

# SQL Server
echo -e "${BLUE}→ SQL Server${NC}"
SQL_SERVERS=$(az sql server list -g "$RG" --query "[].{name:name, state:state, fqdn:fullyQualifiedDomainName}" -o json 2>/dev/null || echo "[]")
SQL_COUNT=$(echo "$SQL_SERVERS" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
check "SQL Server exists (found: $SQL_COUNT)" "$([ "$SQL_COUNT" -gt 0 ] && echo true || echo false)"

if [[ "$SQL_COUNT" -gt 0 ]]; then
  SQL_NAME=$(echo "$SQL_SERVERS" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['name'])" 2>/dev/null)
  SQL_STATE=$(echo "$SQL_SERVERS" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['state'])" 2>/dev/null)
  SQL_FQDN=$(echo "$SQL_SERVERS" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['fqdn'])" 2>/dev/null)
  check "SQL Server is ready (state: $SQL_STATE)" "$([ "$SQL_STATE" == "Ready" ] && echo true || echo false)"
  echo -e "  ${BLUE}  FQDN: $SQL_FQDN${NC}"

  # Databases
  echo -e "${BLUE}→ SQL Databases${NC}"
  DB_LIST=$(az sql db list -g "$RG" -s "$SQL_NAME" --query "[?name!='master'].{name:name, status:status, sku:currentSku.name}" -o json 2>/dev/null || echo "[]")
  DB_COUNT=$(echo "$DB_LIST" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
  check "SQL databases exist (found: $DB_COUNT, excluding master)" "$([ "$DB_COUNT" -gt 0 ] && echo true || echo false)"

  if [[ "$DB_COUNT" -gt 0 ]]; then
    ONLINE_COUNT=$(echo "$DB_LIST" | python3 -c "import sys,json; print(len([d for d in json.load(sys.stdin) if d.get('status')=='Online']))" 2>/dev/null || echo "0")
    check "SQL databases are online ($ONLINE_COUNT/$DB_COUNT online)" "$([ "$ONLINE_COUNT" -eq "$DB_COUNT" ] && echo true || echo false)"

    echo "$DB_LIST" | python3 -c "
import sys, json
dbs = json.load(sys.stdin)
for d in dbs:
    icon = '▶' if d.get('status') == 'Online' else '⏸'
    print(f\"    {icon} {d['name']} — {d.get('status', 'unknown')} (SKU: {d.get('sku', 'N/A')})\")
" 2>/dev/null
  fi

  # Firewall rules
  echo -e "${BLUE}→ SQL Firewall Rules${NC}"
  FW_COUNT=$(az sql server firewall-rule list -g "$RG" -s "$SQL_NAME" --query "length([])" -o tsv 2>/dev/null || echo "0")
  check "Firewall rules configured (found: $FW_COUNT)" "$([ "$FW_COUNT" -gt 0 ] && echo true || echo false)"
fi

# Cosmos DB
echo -e "${BLUE}→ Cosmos DB${NC}"
COSMOS_LIST=$(az cosmosdb list -g "$RG" --query "[].{name:name, state:provisioningState, kind:kind}" -o json 2>/dev/null || echo "[]")
COSMOS_COUNT=$(echo "$COSMOS_LIST" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

if [[ "$COSMOS_COUNT" -gt 0 ]]; then
  check "Cosmos DB account exists (found: $COSMOS_COUNT)" "true"
  COSMOS_NAME=$(echo "$COSMOS_LIST" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['name'])" 2>/dev/null)
  COSMOS_STATE=$(echo "$COSMOS_LIST" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['state'])" 2>/dev/null)
  check "Cosmos DB is ready (state: $COSMOS_STATE)" "$([ "$COSMOS_STATE" == "Succeeded" ] && echo true || echo false)"

  # Check if Cosmos DB endpoint is responding
  COSMOS_ENDPOINT=$(az cosmosdb show -g "$RG" -n "$COSMOS_NAME" --query "documentEndpoint" -o tsv 2>/dev/null || echo "")
  if [[ -n "$COSMOS_ENDPOINT" ]]; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$COSMOS_ENDPOINT" 2>/dev/null || echo "000")
    check "Cosmos DB endpoint responding (HTTP: $HTTP_CODE)" "$([ "$HTTP_CODE" == "401" ] || [ "$HTTP_CODE" == "200" ] && echo true || echo false)"
  fi
else
  warn "No Cosmos DB account found in $RG (may be by design)"
fi

# Summary
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "  Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}, ${YELLOW}${WARN} warnings${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

[[ $FAIL -gt 0 ]] && exit 1
exit 0
