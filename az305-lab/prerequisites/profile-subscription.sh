#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# AZ-305 Lab — Subscription Profiler
#
# Discovers policy constraints, regional restrictions, and quota limits
# BEFORE deploying any Terraform modules.
#
# Outputs: modules/subscription-profile.auto.tfvars
#   → Consumed by all modules to set policy-compliant defaults.
#
# Approach:
#   - Read-only APIs where possible (VM SKUs, provider registrations)
#   - Minimal probe resources for policy/quota detection. Probes that FAIL
#     create nothing (Azure rejects the request before provisioning). Probes
#     that SUCCEED create a temporary resource that is immediately deleted.
#   - All probes live in a single RG that is auto-cleaned on exit.
#   - Total probe footprint: 1 RG + 1 storage account + 1 EH namespace
#     + 1 SQL server (if region works) + 1 App Service Plan (if region works)
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

PRIMARY_REGION="eastus"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --region) PRIMARY_REGION="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--region <azure-region>]"
      echo "  Profiles Azure subscription for policy constraints."
      echo "  Default region: eastus"
      exit 0
      ;;
    *) PRIMARY_REGION="$1"; shift ;;
  esac
done

PROBE_SUFFIX="p$(date +%s | tail -c 6)"
PROBE_RG="az305-probe-${PROBE_SUFFIX}"
FALLBACK_REGIONS=("centralus" "westus2" "northeurope" "eastus2")
SUBSCRIPTION_ID=$(az account show --query "id" --output tsv 2>/dev/null)
SUBSCRIPTION_NAME=$(az account show --query "name" --output tsv 2>/dev/null)

declare -A PROFILE
PROBE_RG_CREATED=false

header() { echo -e "\n${BOLD}── $1 ──${NC}"; }
pass()   { echo -e "  ${GREEN}✓${NC} $1"; }
fail()   { echo -e "  ${RED}✗${NC} $1"; }
warn()   { echo -e "  ${YELLOW}⚠${NC} $1"; }
info()   { echo -e "  ${CYAN}ℹ${NC} $1"; }

cleanup() {
  if [[ "$PROBE_RG_CREATED" == "true" ]]; then
    echo -e "\n${BLUE}Cleaning up probe resources...${NC}"
    az group delete --name "$PROBE_RG" --yes --no-wait 2>/dev/null || true
    pass "Probe resource group deletion initiated"
  fi
  rm -f /tmp/az305-probe-*.json 2>/dev/null || true
}
trap cleanup EXIT

echo -e "${BOLD}AZ-305 Lab — Subscription Profiler${NC}"
echo -e "Subscription: ${CYAN}${SUBSCRIPTION_NAME}${NC}"
echo -e "Primary region: ${CYAN}${PRIMARY_REGION}${NC}"

###############################################################################
# 1. VM SKU Availability (READ-ONLY — no resources created)
###############################################################################
header "VM SKU Availability ($PRIMARY_REGION)"

PREFERRED_SKUS=("Standard_B1s" "Standard_B2s" "Standard_B1ms" "Standard_D2s_v5" "Standard_D2as_v5" "Standard_D2s_v3" "Standard_DC2s_v3")
VM_SIZE=""

AVAILABLE_SKUS=$(az vm list-skus --location "$PRIMARY_REGION" --resource-type virtualMachines \
  --query "[].name" --output tsv 2>/dev/null || echo "")

for sku in "${PREFERRED_SKUS[@]}"; do
  if echo "$AVAILABLE_SKUS" | grep -qx "$sku"; then
    VM_SIZE="$sku"
    pass "$sku — available (selected)"
    break
  fi
done

if [[ -z "$VM_SIZE" ]]; then
  warn "No preferred VM SKU available in $PRIMARY_REGION"
  VM_SIZE=$(echo "$AVAILABLE_SKUS" | head -1)
  if [[ -n "$VM_SIZE" ]]; then
    warn "Falling back to: $VM_SIZE"
  else
    fail "No VM SKUs found in $PRIMARY_REGION"
    VM_SIZE="Standard_DC2s_v3"
  fi
fi
PROFILE[vm_size]="$VM_SIZE"

###############################################################################
# 2. Resource Provider Registrations (READ-ONLY)
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
PROVIDERS_REGISTERED=0

for provider in "${REQUIRED_PROVIDERS[@]}"; do
  if echo "$REGISTERED_JSON" | grep -qi "\"$provider\""; then
    PROVIDERS_REGISTERED=$((PROVIDERS_REGISTERED + 1))
  else
    warn "$provider — not registered, registering..."
    az provider register --namespace "$provider" --output none 2>/dev/null || true
  fi
done
pass "$PROVIDERS_REGISTERED/${#REQUIRED_PROVIDERS[@]} providers registered"

###############################################################################
# 3. SQL Server Regional Availability (PROBE)
#    Attempts az sql server create per region. Blocked regions return an error
#    immediately without creating anything. First working region creates a
#    server which is deleted immediately.
###############################################################################
header "SQL Server Regional Availability"

SQL_REGION=""

# Create the probe RG (shared by all probes)
az group create --name "$PROBE_RG" --location "$PRIMARY_REGION" --output none 2>/dev/null
PROBE_RG_CREATED=true

CURRENT_USER_OID=$(az ad signed-in-user show --query id --output tsv 2>/dev/null || echo "00000000-0000-0000-0000-000000000000")

for region in "$PRIMARY_REGION" "${FALLBACK_REGIONS[@]}"; do
  sql_name="az305-probe-sql-${PROBE_SUFFIX}"
  sql_rg="az305-probe-sql-${region}-${PROBE_SUFFIX}"

  # SQL Server requires RG in same region
  az group create --name "$sql_rg" --location "$region" --output none 2>/dev/null || true

  # Attempt creation; capture exit code separately from output
  set +e
  error_output=$(az sql server create \
    --name "$sql_name" \
    --resource-group "$sql_rg" \
    --location "$region" \
    --enable-ad-only-auth \
    --external-admin-principal-type User \
    --external-admin-name "probe-admin" \
    --external-admin-sid "$CURRENT_USER_OID" \
    --output none \
    2>&1)
  create_exit=$?
  set -e

  if [[ $create_exit -eq 0 ]]; then
    SQL_REGION="$region"
    pass "$region — available"
    az group delete --name "$sql_rg" --yes --no-wait 2>/dev/null || true
    break
  elif echo "$error_output" | grep -qi "RegionDoesNotAllowProvisioning\|ProvisioningDisabled"; then
    info "$region — provisioning blocked"
    az group delete --name "$sql_rg" --yes --no-wait 2>/dev/null || true
  elif echo "$error_output" | grep -qi "RequestDisallowedByPolicy"; then
    info "$region — denied by policy"
    az group delete --name "$sql_rg" --yes --no-wait 2>/dev/null || true
  else
    info "$region — unavailable ($(echo "$error_output" | grep -oE 'Code: \S+' | head -1))"
    az group delete --name "$sql_rg" --yes --no-wait 2>/dev/null || true
  fi
done

if [[ -z "$SQL_REGION" ]]; then
  fail "No region found for SQL Server — trying centralus as default"
  SQL_REGION="centralus"
fi
PROFILE[sql_location]="$SQL_REGION"

###############################################################################
# 4. App Service Regional Availability (PROBE)
#    Same pattern as SQL: blocked regions fail immediately (nothing created).
#    First working region creates a plan which is deleted immediately.
#    Uses a separate RG per attempt because App Service binds SKU to RG+region.
###############################################################################
header "App Service Regional Availability"

APPSERVICE_REGION=""

for region in "$PRIMARY_REGION" "${FALLBACK_REGIONS[@]}"; do
  asp_rg="az305-probe-asp-${region}-${PROBE_SUFFIX}"
  az group create --name "$asp_rg" --location "$region" --output none 2>/dev/null || true

  asp_name="az305-probe-asp-${PROBE_SUFFIX}"
  result=$(az appservice plan create \
    --name "$asp_name" \
    --resource-group "$asp_rg" \
    --location "$region" \
    --sku F1 \
    --is-linux \
    2>&1 || true)

  if echo "$result" | grep -qi "Unauthorized\|quota\|not available\|RequestDisallowedByPolicy"; then
    info "$region — blocked"
    az group delete --name "$asp_rg" --yes --no-wait 2>/dev/null || true
  elif az appservice plan show --name "$asp_name" --resource-group "$asp_rg" --query "name" --output tsv 2>/dev/null > /dev/null; then
    APPSERVICE_REGION="$region"
    pass "$region — available"
    az group delete --name "$asp_rg" --yes --no-wait 2>/dev/null || true
    break
  else
    info "$region — error"
    az group delete --name "$asp_rg" --yes --no-wait 2>/dev/null || true
  fi
done

if [[ -z "$APPSERVICE_REGION" ]]; then
  fail "No region found for App Service — trying centralus as default"
  APPSERVICE_REGION="centralus"
fi
PROFILE[appservice_location]="$APPSERVICE_REGION"

###############################################################################
# 5. Storage & Messaging Policy Detection (PROBE — creates minimal resources)
#    These are modify/append policies that can only be detected post-creation.
#    We create 1 storage account + 1 Event Hub namespace, inspect, then clean up.
###############################################################################
header "Modify/Append Policy Detection (creates temporary probe resources)"

# -- Storage Account Probe --
SA_NAME="az305prf${PROBE_SUFFIX}"
info "Creating probe storage account ($SA_NAME)..."
az storage account create \
  --name "$SA_NAME" \
  --resource-group "$PROBE_RG" \
  --location "$PRIMARY_REGION" \
  --sku Standard_LRS \
  --output none 2>/dev/null

SA_JSON=$(az storage account show --name "$SA_NAME" --resource-group "$PROBE_RG" --output json 2>/dev/null)

SHARED_KEY=$(echo "$SA_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('allowSharedKeyAccess', True))" 2>/dev/null || echo "True")
PUBLIC_ACCESS=$(echo "$SA_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('allowBlobPublicAccess', True))" 2>/dev/null || echo "True")

if [[ "$SHARED_KEY" == "False" ]]; then
  warn "Storage: shared key access DISABLED by policy"
  PROFILE[storage_shared_key_enabled]="false"
  PROFILE[storage_use_azuread]="true"
else
  pass "Storage: shared key access allowed"
  PROFILE[storage_shared_key_enabled]="true"
  PROFILE[storage_use_azuread]="false"
fi

if [[ "$PUBLIC_ACCESS" == "False" ]]; then
  warn "Storage: public blob access DISABLED by policy"
  PROFILE[storage_allow_public_access]="false"
else
  pass "Storage: public blob access allowed"
  PROFILE[storage_allow_public_access]="true"
fi

# -- Event Hub Namespace Probe (detects messaging local auth policy) --
EHN_NAME="az305prfehn${PROBE_SUFFIX}"
info "Creating probe Event Hub namespace ($EHN_NAME)..."
az eventhubs namespace create \
  --name "$EHN_NAME" \
  --resource-group "$PROBE_RG" \
  --location "$PRIMARY_REGION" \
  --sku Standard \
  --output none 2>/dev/null || true

EH_LOCAL_AUTH=$(az eventhubs namespace show --name "$EHN_NAME" --resource-group "$PROBE_RG" \
  --query "disableLocalAuth" --output tsv 2>/dev/null || echo "false")

if [[ "$EH_LOCAL_AUTH" == "true" ]]; then
  warn "Messaging: local auth DISABLED by policy (Event Hubs, Service Bus, Cosmos)"
  PROFILE[eventhub_local_auth]="false"
  PROFILE[servicebus_local_auth]="false"
  PROFILE[cosmosdb_local_auth_disabled]="true"
else
  pass "Messaging: local auth allowed"
  PROFILE[eventhub_local_auth]="true"
  PROFILE[servicebus_local_auth]="true"
  PROFILE[cosmosdb_local_auth_disabled]="false"
fi

# -- Resource Group Tag Probe (check auto-added tags) --
RG_TAGS=$(az group show --name "$PROBE_RG" --query "tags" --output json 2>/dev/null || echo "{}")
if echo "$RG_TAGS" | grep -q "rg-class"; then
  warn "Azure auto-adds 'rg-class' tag to resource groups"
  PROFILE[rg_has_auto_tags]="true"
else
  pass "No auto-added resource group tags detected"
  PROFILE[rg_has_auto_tags]="false"
fi

###############################################################################
# 6. Generate Profile
###############################################################################
header "Generating Subscription Profile"

cat > "$PROFILE_FILE" << TFVARS
# =============================================================================
# AZ-305 Lab — Subscription Profile (Auto-Generated)
# =============================================================================
# Generated by: prerequisites/profile-subscription.sh
# Date: $(date -u '+%Y-%m-%d %H:%M UTC')
# Subscription: ${SUBSCRIPTION_NAME}
#
# Detection methods:
#   - VM SKUs: az vm list-skus (read-only)
#   - SQL/AppService regions: probe create (blocked regions fail instantly, no resource created)
#   - Storage/messaging policies: probe resources (created + auto-cleaned)
#   - Provider registrations: az provider list (read-only)
#
# All modules reference these values to avoid policy conflicts.
# Re-run the profiler if you change subscriptions.
# =============================================================================

# --- VM Configuration ---
vm_size = "${PROFILE[vm_size]}"

# --- Regional Overrides ---
sql_location        = "${PROFILE[sql_location]}"
appservice_location = "${PROFILE[appservice_location]}"

# --- Storage Policies ---
storage_shared_key_enabled  = ${PROFILE[storage_shared_key_enabled]}
storage_use_azuread         = ${PROFILE[storage_use_azuread]}
storage_allow_public_access = ${PROFILE[storage_allow_public_access]}

# --- Authentication Policies ---
eventhub_local_auth_enabled   = ${PROFILE[eventhub_local_auth]}
servicebus_local_auth_enabled = ${PROFILE[servicebus_local_auth]}
cosmosdb_local_auth_disabled  = ${PROFILE[cosmosdb_local_auth_disabled]}

# --- Resource Group Tags ---
rg_has_auto_tags = ${PROFILE[rg_has_auto_tags]}
TFVARS

pass "Written to: modules/subscription-profile.auto.tfvars"

echo ""
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo -e "${BOLD}  Subscription Profile Complete${NC}"
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo -e "  VM Size:            ${GREEN}${PROFILE[vm_size]}${NC}"
echo -e "  SQL Region:         ${GREEN}${PROFILE[sql_location]}${NC}"
echo -e "  App Service Region: ${GREEN}${PROFILE[appservice_location]}${NC}"
echo -e "  Storage Keys:       $([ "${PROFILE[storage_shared_key_enabled]}" == "true" ] && echo "${GREEN}allowed${NC}" || echo "${YELLOW}disabled by policy${NC}")"
echo -e "  Public Blob Access: $([ "${PROFILE[storage_allow_public_access]}" == "true" ] && echo "${GREEN}allowed${NC}" || echo "${YELLOW}disabled by policy${NC}")"
echo -e "  Local Auth:         $([ "${PROFILE[eventhub_local_auth]}" == "true" ] && echo "${GREEN}allowed${NC}" || echo "${YELLOW}disabled by policy${NC}")"
echo -e "  Auto RG Tags:       $([ "${PROFILE[rg_has_auto_tags]}" == "true" ] && echo "${YELLOW}yes (rg-class)${NC}" || echo "${GREEN}none${NC}")"
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Next: Run deploy-all.sh to deploy all modules using these settings.${NC}"
