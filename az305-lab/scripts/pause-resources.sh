#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# pause-resources.sh — Deallocate/stop pausable AZ-305 lab resources
# Usage: ./scripts/pause-resources.sh
###############################################################################

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  AZ-305 Lab — Pause Resources${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# ── Deallocate VMs ──────────────────────────────────────────────────────────
echo -e "${BLUE}→ Finding lab VMs to deallocate...${NC}"
VM_IDS=$(az vm list --query "[?tags.Lab=='AZ-305'].id" -o tsv 2>/dev/null || true)

if [[ -n "$VM_IDS" ]]; then
  VM_COUNT=$(echo "$VM_IDS" | wc -l | tr -d ' ')
  echo -e "${BLUE}  Found ${VM_COUNT} VM(s). Deallocating...${NC}"

  echo "$VM_IDS" | while read -r vm_id; do
    VM_NAME=$(az vm show --ids "$vm_id" --query "name" -o tsv 2>/dev/null || echo "unknown")
    echo -e "${YELLOW}  ⏸ Deallocating: ${VM_NAME}${NC}"
  done

  az vm deallocate --ids $VM_IDS --no-wait 2>/dev/null || {
    echo -e "${RED}  ✗ Some VMs failed to deallocate. Check Azure portal.${NC}"
  }
  echo -e "${GREEN}  ✓ VM deallocation commands sent (--no-wait)${NC}"
else
  echo -e "${YELLOW}  No lab VMs found to deallocate.${NC}"
fi

# ── Stop App Services ───────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}→ Finding lab App Services to stop...${NC}"
APP_IDS=$(az webapp list --query "[?tags.Lab=='AZ-305'].{id:id, name:name, rg:resourceGroup}" -o json 2>/dev/null || echo "[]")
APP_COUNT=$(echo "$APP_IDS" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

if [[ "$APP_COUNT" -gt 0 ]]; then
  echo -e "${BLUE}  Found ${APP_COUNT} App Service(s). Stopping...${NC}"
  echo "$APP_IDS" | python3 -c "
import sys, json
apps = json.load(sys.stdin)
for app in apps:
    print(f\"{app['name']}|{app['rg']}\")
" 2>/dev/null | while IFS='|' read -r name rg; do
    echo -e "${YELLOW}  ⏸ Stopping: ${name}${NC}"
    az webapp stop --name "$name" --resource-group "$rg" 2>/dev/null || {
      echo -e "${RED}    ✗ Failed to stop ${name}${NC}"
    }
  done
  echo -e "${GREEN}  ✓ App Services stopped${NC}"
else
  echo -e "${YELLOW}  No lab App Services found.${NC}"
fi

# ── Stop Function Apps ──────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}→ Finding lab Function Apps to stop...${NC}"
FUNC_IDS=$(az functionapp list --query "[?tags.Lab=='AZ-305'].{name:name, rg:resourceGroup}" -o json 2>/dev/null || echo "[]")
FUNC_COUNT=$(echo "$FUNC_IDS" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

if [[ "$FUNC_COUNT" -gt 0 ]]; then
  echo -e "${BLUE}  Found ${FUNC_COUNT} Function App(s). Stopping...${NC}"
  echo "$FUNC_IDS" | python3 -c "
import sys, json
apps = json.load(sys.stdin)
for app in apps:
    print(f\"{app['name']}|{app['rg']}\")
" 2>/dev/null | while IFS='|' read -r name rg; do
    echo -e "${YELLOW}  ⏸ Stopping: ${name}${NC}"
    az functionapp stop --name "$name" --resource-group "$rg" 2>/dev/null || {
      echo -e "${RED}    ✗ Failed to stop ${name}${NC}"
    }
  done
  echo -e "${GREEN}  ✓ Function Apps stopped${NC}"
else
  echo -e "${YELLOW}  No lab Function Apps found.${NC}"
fi

# ── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✓ Pause commands completed${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Resources that are now paused (no compute charges):${NC}"
echo -e "  • Virtual Machines (deallocated — no CPU/RAM charges)"
echo -e "  • App Services (stopped — no compute charges on non-Free tiers)"
echo -e "  • Function Apps (stopped)"
echo ""
echo -e "${YELLOW}Resources that CANNOT be paused and still incur costs:${NC}"
echo -e "  • Storage Accounts (charged for stored data + transactions)"
echo -e "  • Key Vault (charged per operation; minimal at rest)"
echo -e "  • Log Analytics Workspace (data ingestion + retention)"
echo -e "  • Application Insights (data ingestion)"
echo -e "  • SQL Databases (charged per DTU/vCore while provisioned)"
echo -e "  • Cosmos DB (charged per RU/s while provisioned)"
echo -e "  • Public IP addresses (static IPs charged while allocated)"
echo -e "  • Load Balancers (Standard SKU charged while deployed)"
echo -e "  • VNet/NSGs/Route Tables (free)"
echo ""
echo -e "${BLUE}Estimated savings from pausing:${NC}"
echo -e "  • VM deallocation saves ~\$0.50–\$5.00/hr depending on SKU"
echo -e "  • App Service stops save plan cost (Basic: ~\$0.075/hr, Standard: ~\$0.10/hr)"
echo -e ""
echo -e "${BLUE}To resume resources: ${NC}./scripts/resume-resources.sh"
