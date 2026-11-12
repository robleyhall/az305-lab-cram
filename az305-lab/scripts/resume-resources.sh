#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# resume-resources.sh — Resume paused AZ-305 lab resources
# Usage: ./scripts/resume-resources.sh
###############################################################################

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  AZ-305 Lab — Resume Resources${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# ── Start VMs ───────────────────────────────────────────────────────────────
echo -e "${BLUE}→ Finding deallocated lab VMs...${NC}"
VM_IDS=$(az vm list --query "[?tags.Lab=='AZ-305' && powerState!='VM running'].id" -o tsv 2>/dev/null || true)

if [[ -n "$VM_IDS" ]]; then
  VM_COUNT=$(echo "$VM_IDS" | wc -l | tr -d ' ')
  echo -e "${BLUE}  Found ${VM_COUNT} stopped VM(s). Starting...${NC}"

  echo "$VM_IDS" | while read -r vm_id; do
    VM_NAME=$(az vm show --ids "$vm_id" --query "name" -o tsv 2>/dev/null || echo "unknown")
    echo -e "${GREEN}  ▶ Starting: ${VM_NAME}${NC}"
  done

  az vm start --ids $VM_IDS --no-wait 2>/dev/null || {
    echo -e "${RED}  ✗ Some VMs failed to start. Check Azure portal.${NC}"
  }
  echo -e "${GREEN}  ✓ VM start commands sent (--no-wait)${NC}"
else
  echo -e "${YELLOW}  No stopped lab VMs found.${NC}"
fi

# ── Start App Services ──────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}→ Finding stopped lab App Services...${NC}"
APP_DATA=$(az webapp list --query "[?tags.Lab=='AZ-305' && state!='Running'].{name:name, rg:resourceGroup}" -o json 2>/dev/null || echo "[]")
APP_COUNT=$(echo "$APP_DATA" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

if [[ "$APP_COUNT" -gt 0 ]]; then
  echo -e "${BLUE}  Found ${APP_COUNT} stopped App Service(s). Starting...${NC}"
  echo "$APP_DATA" | python3 -c "
import sys, json
apps = json.load(sys.stdin)
for app in apps:
    print(f\"{app['name']}|{app['rg']}\")
" 2>/dev/null | while IFS='|' read -r name rg; do
    echo -e "${GREEN}  ▶ Starting: ${name}${NC}"
    az webapp start --name "$name" --resource-group "$rg" 2>/dev/null || {
      echo -e "${RED}    ✗ Failed to start ${name}${NC}"
    }
  done
  echo -e "${GREEN}  ✓ App Services started${NC}"
else
  echo -e "${YELLOW}  No stopped lab App Services found.${NC}"
fi

# ── Start Function Apps ─────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}→ Finding stopped lab Function Apps...${NC}"
FUNC_DATA=$(az functionapp list --query "[?tags.Lab=='AZ-305' && state!='Running'].{name:name, rg:resourceGroup}" -o json 2>/dev/null || echo "[]")
FUNC_COUNT=$(echo "$FUNC_DATA" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

if [[ "$FUNC_COUNT" -gt 0 ]]; then
  echo -e "${BLUE}  Found ${FUNC_COUNT} stopped Function App(s). Starting...${NC}"
  echo "$FUNC_DATA" | python3 -c "
import sys, json
apps = json.load(sys.stdin)
for app in apps:
    print(f\"{app['name']}|{app['rg']}\")
" 2>/dev/null | while IFS='|' read -r name rg; do
    echo -e "${GREEN}  ▶ Starting: ${name}${NC}"
    az functionapp start --name "$name" --resource-group "$rg" 2>/dev/null || {
      echo -e "${RED}    ✗ Failed to start ${name}${NC}"
    }
  done
  echo -e "${GREEN}  ✓ Function Apps started${NC}"
else
  echo -e "${YELLOW}  No stopped lab Function Apps found.${NC}"
fi

# ── Verification ────────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}→ Waiting 30 seconds for resources to start...${NC}"
sleep 30

echo -e "${BLUE}→ Verifying resource status...${NC}"
echo ""

echo -e "${BLUE}  Virtual Machines:${NC}"
az vm list --query "[?tags.Lab=='AZ-305'].{Name:name, Status:powerState, Location:location}" -o table 2>/dev/null || {
  echo -e "${YELLOW}  Could not retrieve VM status${NC}"
}

echo ""
echo -e "${BLUE}  App Services:${NC}"
az webapp list --query "[?tags.Lab=='AZ-305'].{Name:name, State:state, URL:defaultHostName}" -o table 2>/dev/null || {
  echo -e "${YELLOW}  Could not retrieve App Service status${NC}"
}

echo ""
echo -e "${BLUE}  Function Apps:${NC}"
az functionapp list --query "[?tags.Lab=='AZ-305'].{Name:name, State:state}" -o table 2>/dev/null || {
  echo -e "${YELLOW}  Could not retrieve Function App status${NC}"
}

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✓ Resume commands completed${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Note: VMs were started with --no-wait. Full boot may take 2-5 minutes.${NC}"
echo -e "${YELLOW}Run this script again to re-check status.${NC}"
