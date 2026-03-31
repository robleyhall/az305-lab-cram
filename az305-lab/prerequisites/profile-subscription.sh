#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# AZ-305 Lab — Subscription Profiler
#
# Probes the target Azure subscription to discover policy constraints, regional
# restrictions, and quota limits BEFORE deploying any Terraform modules.
#
# Outputs: modules/subscription-profile.auto.tfvars
#   → Consumed by all modules to set policy-compliant defaults.
#
# Philosophy: Probe-based detection > policy parsing.
#   Rather than parsing policy definitions (fragile, version-dependent),
#   we attempt small test operations and observe what Azure allows/denies.
#   This catches ALL policy effects: deny, modify, append, inherited from
#   management groups — regardless of where they're defined.
#
# Usage: ./prerequisites/profile-subscription.sh [--region eastus]
###############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROFILE_FILE="$LAB_ROOT/modules/subscription-profile.auto.tfvars"

# Default primary region
PRIMARY_REGION="${1:-eastus}"
if [[ "$1" == "--region" ]] && [[ -n "${2:-}" ]]; then
  PRIMARY_REGION="$2"
fi

PROBE_RG="az305-profile-probe-rg"
PROBE_SUFFIX="probe$(date +%s | tail -c 6)"

# Candidate regions to try if primary fails for a service
FALLBACK_REGIONS=("centralus" "westus2" "northeurope" "eastus2")

# Results
declare -A PROFILE

header() { echo -e "\n${BOLD}── $1 ──${NC}"; }
pass()   { echo -e "  ${GREEN}✓${NC} $1"; }
fail()   { echo -e "  ${RED}✗${NC} $1"; }
warn()   { echo -e "  ${YELLOW}⚠${NC} $1"; }
info()   { echo -e "  ${CYAN}ℹ${NC} $1"; }

cleanup() {
  echo -e "\n${BLUE}Cleaning up probe resources...${NC}"
  az group delete --name "$PROBE_RG" --yes --no-wait 2>/dev/null || true
}
trap cleanup EXIT

###############################################################################
# 1. Create probe resource group
###############################################################################
header "Probe Setup"
az group create --name "$PROBE_RG" --location "$PRIMARY_REGION" --output none 2>/dev/null
pass "Probe resource group created in $PRIMARY_REGION"

###############################################################################
# 2. VM SKU Availability
###############################################################################
header "VM SKU Availability ($PRIMARY_REGION)"

PREFERRED_SKUS=("Standard_B1s" "Standard_B2s" "Standard_B1ms" "Standard_D2s_v5" "Standard_D2as_v5" "Standard_D2s_v3" "Standard_DC2s_v3")
VM_SIZE=""

AVAILABLE_SKUS=$(az vm list-skus --location "$PRIMARY_REGION" --resource-type virtualMachines \
  --query "[].name" --output tsv 2>/dev/null || echo "")

for sku in "${PREFERRED_SKUS[@]}"; do
  if echo "$AVAILABLE_SKUS" | grep -qx "$sku"; then
    VM_SIZE="$sku"
    pass "VM SKU: $sku available"
    break
  else
    info "VM SKU: $sku not available"
  fi
done

if [[ -z "$VM_SIZE" ]]; then
  fail "No preferred VM SKU available in $PRIMARY_REGION"
  # Pick first available small SKU
  VM_SIZE=$(az vm list-skus --location "$PRIMARY_REGION" --resource-type virtualMachines \
    --query "[?contains(name,'Standard_D') || contains(name,'Standard_B')].name" \
    --output tsv 2>/dev/null | head -1 || echo "Standard_DC2s_v3")
  warn "Falling back to: $VM_SIZE"
fi
PROFILE[vm_size]="$VM_SIZE"

###############################################################################
# 3. Storage Account Policy Detection
###############################################################################
header "Storage Account Policies"

SA_NAME="az305probe${PROBE_SUFFIX}"
az storage account create \
  --name "$SA_NAME" \
  --resource-group "$PROBE_RG" \
  --location "$PRIMARY_REGION" \
  --sku Standard_LRS \
  --output none 2>/dev/null

# Check if policy disabled shared key access
SHARED_KEY=$(az storage account show --name "$SA_NAME" --resource-group "$PROBE_RG" \
  --query "allowSharedKeyAccess" --output tsv 2>/dev/null || echo "null")

if [[ "$SHARED_KEY" == "false" ]]; then
  warn "Storage: shared key access DISABLED by policy"
  PROFILE[storage_shared_key_enabled]="false"
  PROFILE[storage_use_azuread]="true"
else
  pass "Storage: shared key access allowed"
  PROFILE[storage_shared_key_enabled]="true"
  PROFILE[storage_use_azuread]="false"
fi

# Check if policy disabled public blob access
PUBLIC_ACCESS=$(az storage account show --name "$SA_NAME" --resource-group "$PROBE_RG" \
  --query "allowBlobPublicAccess" --output tsv 2>/dev/null || echo "null")

if [[ "$PUBLIC_ACCESS" == "false" ]]; then
  warn "Storage: public blob access DISABLED by policy"
  PROFILE[storage_allow_public_access]="false"
else
  pass "Storage: public blob access allowed"
  PROFILE[storage_allow_public_access]="true"
fi

###############################################################################
# 4. SQL Server Regional Availability
###############################################################################
header "SQL Server Availability"

SQL_REGION=""
# Try primary region first, then fallbacks
for region in "$PRIMARY_REGION" "${FALLBACK_REGIONS[@]}"; do
  result=$(az sql server create \
    --name "az305-probe-sql-${PROBE_SUFFIX}" \
    --resource-group "$PROBE_RG" \
    --location "$region" \
    --enable-ad-only-auth \
    --external-admin-principal-type User \
    --external-admin-name "probe" \
    --external-admin-sid "00000000-0000-0000-0000-000000000000" \
    2>&1 || true)

  if echo "$result" | grep -qi "RegionDoesNotAllowProvisioning\|ProvisioningDisabled\|RequestDisallowedByPolicy"; then
    info "SQL Server: $region — blocked"
    continue
  elif echo "$result" | grep -qi "error\|Error"; then
    # Might be an auth error on the probe SID — that's fine, the server was created
    # Check if it exists
    if az sql server show --name "az305-probe-sql-${PROBE_SUFFIX}" --resource-group "$PROBE_RG" --query "name" --output tsv 2>/dev/null; then
      SQL_REGION="$region"
      pass "SQL Server: $region — available"
      az sql server delete --name "az305-probe-sql-${PROBE_SUFFIX}" --resource-group "$PROBE_RG" --yes 2>/dev/null &
      break
    else
      info "SQL Server: $region — error ($(echo "$result" | grep -oE 'Code: \S+' | head -1))"
      continue
    fi
  else
    SQL_REGION="$region"
    pass "SQL Server: $region — available"
    az sql server delete --name "az305-probe-sql-${PROBE_SUFFIX}" --resource-group "$PROBE_RG" --yes 2>/dev/null &
    break
  fi
done

if [[ -n "$SQL_REGION" ]]; then
  PROFILE[sql_location]="$SQL_REGION"
else
  fail "SQL Server: no available region found"
  PROFILE[sql_location]="centralus"
fi

###############################################################################
# 5. App Service Availability
###############################################################################
header "App Service Availability"

APPSERVICE_REGION=""
for region in "$PRIMARY_REGION" "${FALLBACK_REGIONS[@]}"; do
  # Need a separate RG per region for App Service (SKU/region binding)
  asp_rg="az305-probe-asp-rg"
  az group create --name "$asp_rg" --location "$region" --output none 2>/dev/null || true

  result=$(az appservice plan create \
    --name "az305-probe-asp-${PROBE_SUFFIX}" \
    --resource-group "$asp_rg" \
    --location "$region" \
    --sku F1 \
    --is-linux \
    2>&1 || true)

  if echo "$result" | grep -qi "Unauthorized\|quota\|not available"; then
    info "App Service: $region — blocked (quota/SKU)"
    az group delete --name "$asp_rg" --yes --no-wait 2>/dev/null || true
    continue
  elif echo "$result" | grep -qi "error\|Error"; then
    info "App Service: $region — error"
    az group delete --name "$asp_rg" --yes --no-wait 2>/dev/null || true
    continue
  else
    APPSERVICE_REGION="$region"
    pass "App Service: $region — available"
    az group delete --name "$asp_rg" --yes --no-wait 2>/dev/null || true
    break
  fi
done

if [[ -n "$APPSERVICE_REGION" ]]; then
  PROFILE[appservice_location]="$APPSERVICE_REGION"
else
  fail "App Service: no available region found"
  PROFILE[appservice_location]="centralus"
fi

###############################################################################
# 6. Messaging Service Auth Policies
###############################################################################
header "Messaging Service Policies"

# Create a quick Event Hub namespace to check if local auth gets disabled
EHN_NAME="az305probeehn${PROBE_SUFFIX}"
az eventhubs namespace create \
  --name "$EHN_NAME" \
  --resource-group "$PROBE_RG" \
  --location "$PRIMARY_REGION" \
  --sku Standard \
  --output none 2>/dev/null || true

EH_LOCAL_AUTH=$(az eventhubs namespace show --name "$EHN_NAME" --resource-group "$PROBE_RG" \
  --query "disableLocalAuth" --output tsv 2>/dev/null || echo "null")

if [[ "$EH_LOCAL_AUTH" == "true" ]]; then
  warn "Event Hubs: local auth DISABLED by policy"
  PROFILE[eventhub_local_auth]="false"
  PROFILE[servicebus_local_auth]="false"  # Same policy usually applies
  PROFILE[cosmosdb_local_auth_disabled]="true"
else
  pass "Event Hubs: local auth allowed"
  PROFILE[eventhub_local_auth]="true"
  PROFILE[servicebus_local_auth]="true"
  PROFILE[cosmosdb_local_auth_disabled]="false"
fi

###############################################################################
# 7. Resource Provider Registrations
###############################################################################
header "Resource Provider Registrations"

REQUIRED_PROVIDERS=(
  Microsoft.Compute Microsoft.Network Microsoft.Storage Microsoft.Sql
  Microsoft.DocumentDB Microsoft.Web Microsoft.KeyVault
  Microsoft.OperationalInsights Microsoft.EventGrid Microsoft.ServiceBus
  Microsoft.ApiManagement Microsoft.RecoveryServices Microsoft.DataFactory
  Microsoft.Batch Microsoft.Migrate Microsoft.EventHub
  Microsoft.ContainerInstance Microsoft.ContainerRegistry
)

REGISTERED_JSON=$(az provider list --query "[?registrationState=='Registered'].namespace" --output json 2>/dev/null || echo "[]")

for provider in "${REQUIRED_PROVIDERS[@]}"; do
  if echo "$REGISTERED_JSON" | grep -qi "\"$provider\""; then
    pass "$provider"
  else
    warn "$provider — registering..."
    az provider register --namespace "$provider" --output none 2>/dev/null || true
  fi
done

###############################################################################
# 8. Check for rg-class tag policy
###############################################################################
header "Resource Group Tag Policies"

RG_TAGS=$(az group show --name "$PROBE_RG" --query "tags" --output json 2>/dev/null || echo "{}")
if echo "$RG_TAGS" | grep -q "rg-class"; then
  warn "Azure auto-adds 'rg-class' tag to resource groups"
  PROFILE[rg_has_auto_tags]="true"
else
  pass "No auto-added resource group tags detected"
  PROFILE[rg_has_auto_tags]="false"
fi

###############################################################################
# 9. Generate Profile File
###############################################################################
header "Generating Subscription Profile"

cat > "$PROFILE_FILE" << TFVARS
# =============================================================================
# AZ-305 Lab — Subscription Profile (Auto-Generated)
# =============================================================================
# Generated by: prerequisites/profile-subscription.sh
# Date: $(date -u '+%Y-%m-%d %H:%M UTC')
# Subscription: $(az account show --query "name" --output tsv 2>/dev/null)
#
# This file captures subscription-specific constraints discovered by probing.
# All modules reference these values to avoid policy conflicts and regional
# restrictions. Re-run the profiler if you change subscriptions.
# =============================================================================

# --- VM Configuration ---
# Cheapest available VM SKU in $PRIMARY_REGION
vm_size = "${PROFILE[vm_size]}"

# --- Regional Overrides ---
# Some services are restricted in certain regions. These are the tested-working
# regions for each service type.
sql_location        = "${PROFILE[sql_location]}"
appservice_location = "${PROFILE[appservice_location]}"

# --- Storage Policies ---
# Subscription policy enforcement on storage accounts
storage_shared_key_enabled = ${PROFILE[storage_shared_key_enabled]}
storage_use_azuread        = ${PROFILE[storage_use_azuread]}
storage_allow_public_access = ${PROFILE[storage_allow_public_access]}

# --- Authentication Policies ---
# Subscription policy enforcement on local/key-based authentication
eventhub_local_auth_enabled    = ${PROFILE[eventhub_local_auth]}
servicebus_local_auth_enabled  = ${PROFILE[servicebus_local_auth]}
cosmosdb_local_auth_disabled   = ${PROFILE[cosmosdb_local_auth_disabled]}

# --- Resource Group Tags ---
# Whether Azure auto-adds tags (e.g., rg-class) to resource groups
rg_has_auto_tags = ${PROFILE[rg_has_auto_tags]}
TFVARS

pass "Profile written to: modules/subscription-profile.auto.tfvars"
echo ""
cat "$PROFILE_FILE"

echo ""
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo -e "${BOLD}  Subscription Profile Complete${NC}"
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo -e "  VM Size:           ${GREEN}${PROFILE[vm_size]}${NC}"
echo -e "  SQL Region:        ${GREEN}${PROFILE[sql_location]}${NC}"
echo -e "  App Service Region:${GREEN}${PROFILE[appservice_location]}${NC}"
echo -e "  Storage Keys:      $([ "${PROFILE[storage_shared_key_enabled]}" == "true" ] && echo "${GREEN}allowed${NC}" || echo "${YELLOW}disabled${NC}")"
echo -e "  Local Auth:        $([ "${PROFILE[eventhub_local_auth]}" == "true" ] && echo "${GREEN}allowed${NC}" || echo "${YELLOW}disabled${NC}")"
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Next: Run deploy-all.sh to deploy all modules using these settings.${NC}"
