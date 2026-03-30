#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# validate-12.sh — Validate Module 12: Migration
# Checks: Migrate project, DMS running, simulated VM accessible
###############################################################################

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

RG="az305-lab-migration"

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
echo -e "${BLUE}  Validating Module 12: Migration${NC}"
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

# Azure Migrate Project
echo -e "${BLUE}→ Azure Migrate Project${NC}"
MIGRATE_LIST=$(az resource list -g "$RG" --resource-type "Microsoft.Migrate/migrateProjects" --query "[].{name:name, state:provisioningState}" -o json 2>/dev/null || echo "[]")
MIGRATE_COUNT=$(echo "$MIGRATE_LIST" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

if [[ "$MIGRATE_COUNT" -gt 0 ]]; then
  check "Azure Migrate project exists (found: $MIGRATE_COUNT)" "true"
  echo "$MIGRATE_LIST" | python3 -c "
import sys, json
for m in json.load(sys.stdin):
    print(f\"    • {m['name']} (state: {m.get('state', 'unknown')})\")
" 2>/dev/null
else
  # Also check for assessment projects
  ASSESS_LIST=$(az resource list -g "$RG" --resource-type "Microsoft.Migrate/assessmentProjects" --query "[].name" -o json 2>/dev/null || echo "[]")
  ASSESS_COUNT=$(echo "$ASSESS_LIST" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
  if [[ "$ASSESS_COUNT" -gt 0 ]]; then
    check "Azure Migrate assessment project exists (found: $ASSESS_COUNT)" "true"
  else
    warn "No Azure Migrate project found in $RG"
  fi
fi

# Database Migration Service
echo -e "${BLUE}→ Database Migration Service${NC}"
DMS_LIST=$(az resource list -g "$RG" --resource-type "Microsoft.DataMigration/services" --query "[].{name:name, state:provisioningState}" -o json 2>/dev/null || echo "[]")
DMS_COUNT=$(echo "$DMS_LIST" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

if [[ "$DMS_COUNT" -gt 0 ]]; then
  check "Database Migration Service exists (found: $DMS_COUNT)" "true"
  DMS_NAME=$(echo "$DMS_LIST" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['name'])" 2>/dev/null)
  DMS_STATE=$(echo "$DMS_LIST" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['state'])" 2>/dev/null)
  check "DMS provisioned (state: $DMS_STATE)" "$([ "$DMS_STATE" == "Succeeded" ] && echo true || echo false)"
else
  # Check for newer DMS (SQL migration)
  DMS_SQL=$(az resource list -g "$RG" --resource-type "Microsoft.DataMigration/sqlMigrationServices" --query "[].name" -o json 2>/dev/null || echo "[]")
  DMS_SQL_COUNT=$(echo "$DMS_SQL" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
  if [[ "$DMS_SQL_COUNT" -gt 0 ]]; then
    check "SQL Migration Service exists (found: $DMS_SQL_COUNT)" "true"
  else
    warn "No Database Migration Service found in $RG"
  fi
fi

# Simulated on-premises VM
echo -e "${BLUE}→ Simulated On-Premises VM${NC}"
VM_LIST=$(az vm list -g "$RG" --show-details --query "[].{name:name, state:powerState, ip:publicIps}" -o json 2>/dev/null || echo "[]")
VM_COUNT=$(echo "$VM_LIST" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

if [[ "$VM_COUNT" -gt 0 ]]; then
  check "Simulated VM exists (found: $VM_COUNT)" "true"

  echo "$VM_LIST" | python3 -c "
import sys, json
for v in json.load(sys.stdin):
    icon = '▶' if v.get('state') == 'VM running' else '⏸'
    ip = v.get('ip', 'none')
    print(f\"    {icon} {v['name']} — {v.get('state', 'unknown')} (IP: {ip})\")
" 2>/dev/null

  RUNNING=$(echo "$VM_LIST" | python3 -c "import sys,json; print(len([v for v in json.load(sys.stdin) if v.get('state')=='VM running']))" 2>/dev/null || echo "0")
  check "Simulated VM running ($RUNNING/$VM_COUNT)" "$([ "$RUNNING" -gt 0 ] && echo true || echo false)"

  # Test SSH/RDP accessibility
  VM_IP=$(echo "$VM_LIST" | python3 -c "import sys,json; print(json.load(sys.stdin)[0].get('ip',''))" 2>/dev/null)
  if [[ -n "$VM_IP" && "$VM_IP" != "None" ]]; then
    # Quick TCP check on port 22 (SSH)
    if timeout 5 bash -c "echo >/dev/tcp/$VM_IP/22" 2>/dev/null; then
      check "VM accessible via SSH ($VM_IP:22)" "true"
    else
      # Try RDP port
      if timeout 5 bash -c "echo >/dev/tcp/$VM_IP/3389" 2>/dev/null; then
        check "VM accessible via RDP ($VM_IP:3389)" "true"
      else
        warn "VM not accessible via SSH (22) or RDP (3389) — may be by design"
      fi
    fi
  else
    warn "No public IP assigned to VM — may only be accessible via private network"
  fi
else
  warn "No VMs found in $RG"
fi

# Additional migration resources
echo -e "${BLUE}→ Additional Resources${NC}"
ALL_RESOURCES=$(az resource list -g "$RG" --query "[].{type:type, name:name}" -o json 2>/dev/null || echo "[]")
RESOURCE_COUNT=$(echo "$ALL_RESOURCES" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
echo -e "  ${BLUE}Total resources in $RG: $RESOURCE_COUNT${NC}"

echo "$ALL_RESOURCES" | python3 -c "
import sys, json
from collections import Counter
resources = json.load(sys.stdin)
types = Counter(r['type'] for r in resources)
for rtype, count in sorted(types.items()):
    short = rtype.split('/')[-1]
    print(f\"    • {short}: {count}\")
" 2>/dev/null

# Summary
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "  Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}, ${YELLOW}${WARN} warnings${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

[[ $FAIL -gt 0 ]] && exit 1
exit 0
