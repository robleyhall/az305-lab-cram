#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# estimate-cost.sh — Estimate costs for AZ-305 lab resources
# Usage: ./scripts/estimate-cost.sh
###############################################################################

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  AZ-305 Lab — Cost Estimate${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Cost lookup table (approximate $/day for common lab SKUs)
# These are rough estimates for East US; actual costs vary by region and discounts.
declare -A COST_PER_DAY=(
  # VMs
  ["Microsoft.Compute/virtualMachines|Standard_B1s"]=0.31
  ["Microsoft.Compute/virtualMachines|Standard_B2s"]=1.25
  ["Microsoft.Compute/virtualMachines|Standard_B2ms"]=2.00
  ["Microsoft.Compute/virtualMachines|Standard_D2s_v3"]=2.30
  ["Microsoft.Compute/virtualMachines|Standard_DS1_v2"]=1.39
  # SQL
  ["Microsoft.Sql/servers/databases|Basic"]=0.15
  ["Microsoft.Sql/servers/databases|S0"]=0.48
  ["Microsoft.Sql/servers/databases|S1"]=0.97
  # Storage
  ["Microsoft.Storage/storageAccounts|Standard_LRS"]=0.06
  ["Microsoft.Storage/storageAccounts|Standard_GRS"]=0.10
  # App Service
  ["Microsoft.Web/sites|B1"]=0.44
  ["Microsoft.Web/sites|S1"]=2.40
  ["Microsoft.Web/sites|F1"]=0.00
  # App Service Plans
  ["Microsoft.Web/serverFarms|B1"]=1.60
  ["Microsoft.Web/serverFarms|S1"]=2.40
  ["Microsoft.Web/serverFarms|F1"]=0.00
  # Key Vault
  ["Microsoft.KeyVault/vaults|standard"]=0.01
  # Cosmos DB
  ["Microsoft.DocumentDB/databaseAccounts|Standard"]=0.77
  # Log Analytics
  ["Microsoft.OperationalInsights/workspaces|PerGB2018"]=0.07
  # Load Balancer
  ["Microsoft.Network/loadBalancers|Standard"]=0.60
  # Public IP
  ["Microsoft.Network/publicIPAddresses|Standard"]=0.14
  # ACI
  ["Microsoft.ContainerInstance/containerGroups|Standard"]=0.73
)

# ── Gather all lab resources ────────────────────────────────────────────────
echo -e "${BLUE}→ Fetching all resources tagged Lab=AZ-305...${NC}"
ALL_RESOURCES=$(az resource list --tag "Lab=AZ-305" -o json 2>/dev/null || echo "[]")
TOTAL_COUNT=$(echo "$ALL_RESOURCES" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

echo -e "${GREEN}  Found ${TOTAL_COUNT} tagged resources${NC}"
echo ""

if [[ "$TOTAL_COUNT" -eq 0 ]]; then
  echo -e "${YELLOW}No lab resources found. Deploy modules first.${NC}"
  exit 0
fi

# ── Group by module ─────────────────────────────────────────────────────────
echo -e "${BLUE}→ Grouping resources by module...${NC}"
echo ""

# Extract and display per-module breakdown
python3 - "$ALL_RESOURCES" << 'PYTHON_SCRIPT'
import json, sys

resources = json.loads(sys.argv[1]) if len(sys.argv) > 1 else []

# Group by module tag
modules = {}
untagged_module = []

for r in resources:
    tags = r.get("tags", {}) or {}
    module = tags.get("Module", "untagged")
    if module not in modules:
        modules[module] = []
    modules[module].append({
        "name": r.get("name", "unknown"),
        "type": r.get("type", "unknown"),
        "sku": (r.get("sku", {}) or {}).get("name", "N/A") if r.get("sku") else "N/A",
        "location": r.get("location", "unknown"),
    })

module_names = {
    "00": "foundation",
    "01": "governance",
    "02": "identity",
    "03": "keyvault",
    "04": "monitoring",
    "05": "ha-dr",
    "06": "storage",
    "07": "databases",
    "08": "data-integration",
    "09": "compute",
    "10": "app-architecture",
    "11": "networking",
    "12": "migration",
}

GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
BLUE = "\033[0;34m"
NC = "\033[0m"

for module_num in sorted(modules.keys()):
    items = modules[module_num]
    label = module_names.get(module_num, module_num)
    print(f"{BLUE}  Module {module_num} ({label}) — {len(items)} resource(s){NC}")
    print(f"  {'Resource Type':<50} {'SKU':<20} {'Name':<30}")
    print(f"  {'─'*50} {'─'*20} {'─'*30}")
    for item in sorted(items, key=lambda x: x["type"]):
        rtype = item["type"]
        if len(rtype) > 48:
            rtype = "…" + rtype[-47:]
        print(f"  {rtype:<50} {item['sku']:<20} {item['name']:<30}")
    print()

PYTHON_SCRIPT

# ── Cost estimation ─────────────────────────────────────────────────────────
echo -e "${BLUE}→ Estimating costs...${NC}"
echo ""

python3 - "$ALL_RESOURCES" << 'COST_SCRIPT'
import json, sys

resources = json.loads(sys.argv[1]) if len(sys.argv) > 1 else []

# Approximate daily cost lookup
cost_map = {
    ("Microsoft.Compute/virtualMachines", "Standard_B1s"): 0.31,
    ("Microsoft.Compute/virtualMachines", "Standard_B2s"): 1.25,
    ("Microsoft.Compute/virtualMachines", "Standard_B2ms"): 2.00,
    ("Microsoft.Compute/virtualMachines", "Standard_D2s_v3"): 2.30,
    ("Microsoft.Compute/virtualMachines", "Standard_DS1_v2"): 1.39,
    ("Microsoft.Sql/servers/databases", "Basic"): 0.15,
    ("Microsoft.Sql/servers/databases", "S0"): 0.48,
    ("Microsoft.Sql/servers/databases", "S1"): 0.97,
    ("Microsoft.Storage/storageAccounts", "Standard_LRS"): 0.06,
    ("Microsoft.Storage/storageAccounts", "Standard_GRS"): 0.10,
    ("Microsoft.Web/sites", "B1"): 0.44,
    ("Microsoft.Web/sites", "S1"): 2.40,
    ("Microsoft.Web/sites", "F1"): 0.00,
    ("Microsoft.Web/serverFarms", "B1"): 1.60,
    ("Microsoft.Web/serverFarms", "S1"): 2.40,
    ("Microsoft.Web/serverFarms", "F1"): 0.00,
    ("Microsoft.KeyVault/vaults", "standard"): 0.01,
    ("Microsoft.DocumentDB/databaseAccounts", "Standard"): 0.77,
    ("Microsoft.OperationalInsights/workspaces", "PerGB2018"): 0.07,
    ("Microsoft.Network/loadBalancers", "Standard"): 0.60,
    ("Microsoft.Network/publicIPAddresses", "Standard"): 0.14,
    ("Microsoft.ContainerInstance/containerGroups", "Standard"): 0.73,
}

# Fallback costs by type
type_fallback = {
    "Microsoft.Compute/virtualMachines": 1.50,
    "Microsoft.Sql/servers/databases": 0.50,
    "Microsoft.Storage/storageAccounts": 0.06,
    "Microsoft.Web/sites": 0.50,
    "Microsoft.Web/serverFarms": 1.50,
    "Microsoft.KeyVault/vaults": 0.01,
    "Microsoft.DocumentDB/databaseAccounts": 0.77,
    "Microsoft.OperationalInsights/workspaces": 0.07,
    "Microsoft.Network/loadBalancers": 0.60,
    "Microsoft.Network/publicIPAddresses": 0.14,
    "Microsoft.ContainerInstance/containerGroups": 0.73,
}

# Free resources
free_types = {
    "Microsoft.Network/virtualNetworks",
    "Microsoft.Network/networkSecurityGroups",
    "Microsoft.Network/routeTables",
    "Microsoft.Network/networkInterfaces",
    "Microsoft.Network/networkWatchers",
    "Microsoft.Authorization/policyAssignments",
    "Microsoft.Authorization/roleDefinitions",
    "Microsoft.ManagedIdentity/userAssignedIdentities",
    "Microsoft.Insights/actionGroups",
    "Microsoft.Insights/activityLogAlerts",
    "Microsoft.Network/privateDnsZones",
    "Microsoft.Network/privateEndpoints",
    "Microsoft.Compute/disks",
}

module_names = {
    "00": "foundation", "01": "governance", "02": "identity",
    "03": "keyvault", "04": "monitoring", "05": "ha-dr",
    "06": "storage", "07": "databases", "08": "data-integration",
    "09": "compute", "10": "app-architecture", "11": "networking",
    "12": "migration",
}

GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
BLUE = "\033[0;34m"
RED = "\033[0;31m"
NC = "\033[0m"

module_costs = {}
total_daily = 0.0
unknown_resources = []

for r in resources:
    tags = r.get("tags", {}) or {}
    module = tags.get("Module", "untagged")
    rtype = r.get("type", "unknown")
    sku = ((r.get("sku", {}) or {}).get("name", "")) if r.get("sku") else ""

    if rtype in free_types:
        daily = 0.0
    elif (rtype, sku) in cost_map:
        daily = cost_map[(rtype, sku)]
    elif rtype in type_fallback:
        daily = type_fallback[rtype]
    else:
        daily = 0.0
        unknown_resources.append(f"{r.get('name', '?')} ({rtype})")

    module_costs.setdefault(module, 0.0)
    module_costs[module] += daily
    total_daily += daily

print(f"  {'Module':<30} {'Daily':<12} {'Monthly (30d)':<12}")
print(f"  {'─'*30} {'─'*12} {'─'*12}")

for mod in sorted(module_costs.keys()):
    daily = module_costs[mod]
    monthly = daily * 30
    label = f"{mod}-{module_names.get(mod, '')}" if mod in module_names else mod
    color = GREEN if daily < 1.0 else (YELLOW if daily < 5.0 else RED)
    print(f"  {label:<30} {color}${daily:>9.2f}{NC}   {color}${monthly:>9.2f}{NC}")

print(f"  {'─'*30} {'─'*12} {'─'*12}")
total_monthly = total_daily * 30
color = GREEN if total_daily < 5.0 else (YELLOW if total_daily < 15.0 else RED)
print(f"  {'TOTAL':<30} {color}${total_daily:>9.2f}{NC}   {color}${total_monthly:>9.2f}{NC}")
print()

if unknown_resources:
    print(f"{YELLOW}  Resources with unknown cost (not in estimate table):{NC}")
    for ur in unknown_resources:
        print(f"{YELLOW}    • {ur}{NC}")
    print()

COST_SCRIPT

# ── Check for untagged lab resources ────────────────────────────────────────
echo -e "${BLUE}→ Checking for untagged resources in az305-lab-* resource groups...${NC}"
UNTAGGED=$(az resource list --query "[?starts_with(resourceGroup, 'az305-lab-') && (tags == null || tags.Lab == null)].{Name:name, Type:type, RG:resourceGroup}" -o json 2>/dev/null || echo "[]")
UNTAGGED_COUNT=$(echo "$UNTAGGED" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

if [[ "$UNTAGGED_COUNT" -gt 0 ]]; then
  echo -e "${YELLOW}⚠ Found ${UNTAGGED_COUNT} untagged resource(s) in az305-lab-* groups:${NC}"
  echo "$UNTAGGED" | python3 -c "
import sys, json
items = json.load(sys.stdin)
for i in items:
    print(f\"  • {i['Name']} ({i['Type']}) in {i['RG']}\")
" 2>/dev/null
  echo -e "${YELLOW}  These may be lab-related but aren't included in cost estimates.${NC}"
  echo -e "${YELLOW}  Consider tagging them with Lab=AZ-305 and a Module tag.${NC}"
else
  echo -e "${GREEN}  ✓ No untagged resources found in az305-lab-* groups.${NC}"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Note: These are rough estimates based on list pricing.${NC}"
echo -e "${BLUE}  Actual costs may vary. Check Azure Cost Management for${NC}"
echo -e "${BLUE}  precise figures. Use pause-resources.sh to reduce costs.${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
