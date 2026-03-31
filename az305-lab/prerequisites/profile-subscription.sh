#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# AZ-305 Lab — Subscription Compatibility Check (Read-Only)
#
# Detects Azure Policy constraints, VM SKU availability, regional
# restrictions, and provider registrations BEFORE deploying any modules.
#
# ALL DETECTION IS READ-ONLY — no resources are created, no cleanup needed.
#
# Detection methods:
#   - VM SKUs:       az vm list-skus (read-only)
#   - Providers:     az provider list (read-only, auto-registers missing)
#   - Policies:      az policy assignment list + az policy definition show (read-only)
#   - Regions:       az provider show (read-only)
#
# Outputs:
#   modules/subscription-profile.env      — TF_VAR_ exports, sourced by deploy scripts
#   modules/subscription-profile.tfvars   — HCL format for manual terraform use
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
PROFILE_ENV="$LAB_ROOT/modules/subscription-profile.env"
PROFILE_TFVARS="$LAB_ROOT/modules/subscription-profile.tfvars"

PRIMARY_REGION="eastus"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --region) PRIMARY_REGION="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--region <azure-region>]"
      echo "  Checks subscription compatibility for AZ-305 lab deployment."
      echo "  All checks are read-only — no resources are created."
      echo "  Default region: eastus"
      exit 0
      ;;
    *) PRIMARY_REGION="$1"; shift ;;
  esac
done

FALLBACK_REGIONS=("centralus" "westus2" "northeurope" "eastus2")
SUBSCRIPTION_ID=$(az account show --query "id" --output tsv 2>/dev/null)
SUBSCRIPTION_NAME=$(az account show --query "name" --output tsv 2>/dev/null)

# Profile values — populated by each detection section
declare -A PROFILE
# Defaults (used when detection cannot determine a value)
PROFILE[vm_size]="Standard_B1s"
PROFILE[sql_location]=""
PROFILE[appservice_location]=""
PROFILE[storage_shared_key_enabled]="true"
PROFILE[storage_public_network_access]="true"
PROFILE[storage_allow_public_access]="true"
PROFILE[keyvault_public_network_access]="true"
PROFILE[sql_public_network_access]="true"
PROFILE[data_factory_public_network]="true"
PROFILE[local_auth_enabled]="true"

header() { echo -e "\n${BOLD}── $1 ──${NC}"; }
pass()   { echo -e "  ${GREEN}✓${NC} $1"; }
fail()   { echo -e "  ${RED}✗${NC} $1"; }
warn()   { echo -e "  ${YELLOW}⚠${NC} $1"; }
info()   { echo -e "  ${CYAN}ℹ${NC} $1"; }

echo -e "${BOLD}AZ-305 Lab — Subscription Compatibility Check${NC}"
echo -e "Subscription: ${CYAN}${SUBSCRIPTION_NAME}${NC} (${SUBSCRIPTION_ID})"
echo -e "Primary region: ${CYAN}${PRIMARY_REGION}${NC}"
echo -e "${CYAN}All checks are read-only — no resources will be created.${NC}"

###############################################################################
# 1. VM SKU Availability (READ-ONLY)
###############################################################################
header "VM SKU Availability ($PRIMARY_REGION)"

PREFERRED_SKUS=("Standard_B1s" "Standard_B2s" "Standard_B1ms" "Standard_D2s_v5" "Standard_D2as_v5" "Standard_D2s_v3" "Standard_DC2s_v3")

AVAILABLE_SKUS=$(az vm list-skus --location "$PRIMARY_REGION" --resource-type virtualMachines \
  --query "[].name" --output tsv 2>/dev/null || echo "")

for sku in "${PREFERRED_SKUS[@]}"; do
  if echo "$AVAILABLE_SKUS" | grep -qx "$sku"; then
    PROFILE[vm_size]="$sku"
    pass "$sku — available (selected)"
    break
  fi
done

if [[ "${PROFILE[vm_size]}" == "Standard_B1s" ]] && ! echo "$AVAILABLE_SKUS" | grep -qx "Standard_B1s"; then
  warn "No preferred VM SKU available in $PRIMARY_REGION"
  FALLBACK_SKU=$(echo "$AVAILABLE_SKUS" | head -1)
  if [[ -n "$FALLBACK_SKU" ]]; then
    PROFILE[vm_size]="$FALLBACK_SKU"
    warn "Falling back to: $FALLBACK_SKU"
  else
    fail "No VM SKUs found in $PRIMARY_REGION — using Standard_DC2s_v3"
    PROFILE[vm_size]="Standard_DC2s_v3"
  fi
fi

###############################################################################
# 2. Resource Provider Registrations (READ-ONLY, auto-registers missing)
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
# 3. Azure Policy Detection (READ-ONLY)
#    Reads policy assignments and definitions to detect Modify/Deny effects
#    that enforce specific settings on lab resources.
###############################################################################
header "Azure Policy Detection"
info "Reading policy assignments and definitions (read-only)..."

POLICY_JSON=$(python3 << 'POLICY_SCRIPT'
import json
import subprocess
import sys

# Fields we look for in policy definitions and the profile keys they map to
TARGETS = {
    "microsoft.storage/storageaccounts/allowsharedkeyaccess":  "storage_shared_key",
    "microsoft.storage/storageaccounts/publicnetworkaccess":   "storage_public_network_access",
    "microsoft.storage/storageaccounts/allowblobpublicaccess": "storage_allow_public_access",
    "microsoft.keyvault/vaults/properties/publicnetworkaccess":     "keyvault_public_network_access",
    "microsoft.keyvault/vaults/publicnetworkaccess":                "keyvault_public_network_access",
    "microsoft.sql/servers/publicnetworkaccess":               "sql_public_network_access",
    "microsoft.datafactory/factories/publicnetworkaccess":     "data_factory_public_network",
    "microsoft.eventhub/namespaces/disablelocalauth":          "eventhub_local_auth",
    "microsoft.servicebus/namespaces/disablelocalauth":        "servicebus_local_auth",
    "microsoft.apimanagement/service/disablelocalauth":        "apim_local_auth",
}

def run_az(*args):
    try:
        result = subprocess.run(
            ["az"] + list(args) + ["--output", "json"],
            capture_output=True, text=True, timeout=30
        )
        if result.returncode == 0 and result.stdout.strip():
            return json.loads(result.stdout)
    except (json.JSONDecodeError, subprocess.TimeoutExpired, FileNotFoundError):
        pass
    return None

def resolve_effect(definition, assignment_params):
    """Resolve effect, handling parameterized effects like [parameters('effect')]."""
    rule = definition.get("policyRule", {})
    effect = rule.get("then", {}).get("effect", "")
    if isinstance(effect, str) and "[parameters(" in effect.lower():
        param_name = effect.split("'")[1] if "'" in effect else "effect"
        if param_name in assignment_params:
            val = assignment_params[param_name]
            return val.get("value", val) if isinstance(val, dict) else val
        def_params = definition.get("parameters", {})
        if param_name in def_params:
            return def_params[param_name].get("defaultValue", "unknown")
    return effect

def find_fields_and_values(obj, found=None):
    """Recursively find field references and enforced values in a policy rule."""
    if found is None:
        found = {}
    if isinstance(obj, dict):
        # Check Modify operations
        if "operations" in obj and isinstance(obj["operations"], list):
            for op in obj["operations"]:
                field = (op.get("field") or "").lower()
                value = op.get("value")
                for target, key in TARGETS.items():
                    if target in field:
                        found[key] = {"field": field, "value": value}
        # Check field conditions (Deny rules)
        if "field" in obj and isinstance(obj["field"], str):
            field = obj["field"].lower()
            for target, key in TARGETS.items():
                if target in field:
                    # For Deny rules, the enforced value comes from the condition
                    if key not in found:
                        found[key] = {"field": field, "value": None}
        for v in obj.values():
            find_fields_and_values(v, found)
    elif isinstance(obj, list):
        for item in obj:
            find_fields_and_values(item, found)
    return found

def analyze_definition(definition, assignment_params):
    """Check if a policy definition enforces any of our target fields."""
    effect = resolve_effect(definition, assignment_params)
    if not isinstance(effect, str):
        return {}
    effect_lower = effect.lower()
    if effect_lower not in ("modify", "deny", "append", "deployifnotexists"):
        return {}
    rule = definition.get("policyRule", {})
    fields = find_fields_and_values(rule)
    results = {}
    for key, info in fields.items():
        results[key] = {
            "effect": effect_lower,
            "policy": definition.get("displayName", definition.get("name", "unknown")),
            "value": info.get("value"),
        }
    return results

# --- Main ---
assignments = run_az("policy", "assignment", "list") or []
if not assignments:
    print(json.dumps({"_error": "Could not read policy assignments. Check permissions."}))
    sys.exit(0)

# Collect unique definition IDs from assignments
def_ids = {}   # id -> assignment_params
set_ids = {}   # id -> assignment_params
for a in assignments:
    pid = a.get("policyDefinitionId", "")
    params = a.get("parameters", {})
    if "/policySetDefinitions/" in pid:
        set_ids[pid] = params
    elif "/policyDefinitions/" in pid:
        def_ids[pid] = params

# Resolve policy set definitions to individual definitions
for set_id, set_params in list(set_ids.items()):
    name = set_id.rsplit("/", 1)[-1]
    set_def = run_az("policy", "set-definition", "show", "--name", name)
    if set_def and "policyDefinitions" in set_def:
        for member in set_def["policyDefinitions"]:
            member_id = member.get("policyDefinitionId", "")
            if "/policyDefinitions/" in member_id and member_id not in def_ids:
                # Merge set-level and member-level parameters
                member_params = {}
                for pk, pv in member.get("parameters", {}).items():
                    if isinstance(pv, dict) and "value" in pv:
                        val = pv["value"]
                        if isinstance(val, str) and "[parameters(" in val:
                            ref = val.split("'")[1] if "'" in val else pk
                            if ref in set_params:
                                member_params[pk] = set_params[ref]
                                continue
                        member_params[pk] = pv
                    else:
                        member_params[pk] = pv
                def_ids[member_id] = member_params

# Analyze each definition
all_findings = {}
seen_names = set()
for def_id, params in def_ids.items():
    name = def_id.rsplit("/", 1)[-1]
    if name in seen_names:
        continue
    seen_names.add(name)
    definition = run_az("policy", "definition", "show", "--name", name)
    if not definition:
        continue
    findings = analyze_definition(definition, params)
    all_findings.update(findings)

print(json.dumps(all_findings))
POLICY_SCRIPT
) || POLICY_JSON="{}"

# Parse policy findings
if echo "$POLICY_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if '_error' not in d else 1)" 2>/dev/null; then

  parse_policy() {
    local key="$1" profile_key="$2" invert="${3:-false}"
    local value
    value=$(echo "$POLICY_JSON" | python3 -c "
import sys, json
d = json.load(sys.stdin)
if '$key' in d:
    v = d['$key'].get('value')
    effect = d['$key'].get('effect', '')
    policy = d['$key'].get('policy', 'unknown')
    print(f'{v}|{effect}|{policy}')
else:
    print('none')
" 2>/dev/null) || value="none"

    if [[ "$value" != "none" ]]; then
      local enforced_value effect policy_name
      enforced_value=$(echo "$value" | cut -d'|' -f1)
      effect=$(echo "$value" | cut -d'|' -f2)
      policy_name=$(echo "$value" | cut -d'|' -f3)

      if [[ "$invert" == "true" ]]; then
        # For disableLocalAuth: policy sets true → our variable should be false
        if [[ "$enforced_value" == "True" || "$enforced_value" == "true" ]]; then
          PROFILE[$profile_key]="false"
        else
          PROFILE[$profile_key]="true"
        fi
      else
        # For allowSharedKeyAccess: policy sets false → our variable is false
        if [[ "$enforced_value" == "False" || "$enforced_value" == "false" ]]; then
          PROFILE[$profile_key]="false"
        elif [[ "$enforced_value" == "True" || "$enforced_value" == "true" ]]; then
          PROFILE[$profile_key]="true"
        elif [[ "$effect" == "deny" || "$effect" == "modify" ]]; then
          # Deny/modify without a clear value — assume restricted
          PROFILE[$profile_key]="false"
        fi
      fi
      warn "$profile_key = ${PROFILE[$profile_key]} (${effect}: ${policy_name})"
    else
      pass "$profile_key = ${PROFILE[$profile_key]} (no enforcing policy found)"
    fi
  }

  parse_policy "storage_shared_key"           "storage_shared_key_enabled"
  parse_policy "storage_public_network_access" "storage_public_network_access"
  parse_policy "storage_allow_public_access"   "storage_allow_public_access"
  parse_policy "keyvault_public_network_access" "keyvault_public_network_access"
  parse_policy "sql_public_network_access"     "sql_public_network_access"
  parse_policy "data_factory_public_network"   "data_factory_public_network"
  # Local auth: disableLocalAuth=true means local_auth_enabled=false (inverted)
  parse_policy "eventhub_local_auth"           "local_auth_enabled" "true"
  parse_policy "servicebus_local_auth"         "local_auth_enabled" "true"
  parse_policy "apim_local_auth"               "local_auth_enabled" "true"

else
  warn "Could not read policy assignments — using permissive defaults."
  warn "You may need Reader or Resource Policy Reader role to read policies."
fi

###############################################################################
# 4. Regional Availability for SQL and App Service (READ-ONLY)
#    Uses provider location metadata. Cannot detect subscription-specific
#    provisioning restrictions (ProvisioningDisabled) — those only surface
#    at deployment time. Defaults to known-good fallback regions.
###############################################################################
header "Regional Availability"

check_region_support() {
  local provider="$1" resource_type="$2" region="$3"
  local locations
  locations=$(az provider show -n "$provider" \
    --query "resourceTypes[?resourceType=='$resource_type'].locations[]" \
    --output tsv 2>/dev/null || echo "")
  # Azure returns location display names (e.g., "East US"), normalize to CLI names
  echo "$locations" | tr '[:upper:]' '[:lower:]' | tr -d ' ' | grep -qx "$(echo "$region" | tr -d '-')"
}

# SQL Server regional check
info "Checking SQL Server availability..."
SQL_REGION=""
for region in "$PRIMARY_REGION" "${FALLBACK_REGIONS[@]}"; do
  if check_region_support "Microsoft.Sql" "servers" "$region"; then
    SQL_REGION="$region"
    pass "SQL Server: $region — supported"
    break
  else
    info "SQL Server: $region — not listed for this provider"
  fi
done
if [[ -z "$SQL_REGION" ]]; then
  SQL_REGION="centralus"
  warn "SQL Server: defaulting to centralus"
fi
PROFILE[sql_location]="$SQL_REGION"

# App Service regional check
info "Checking App Service availability..."
APP_REGION=""
for region in "$PRIMARY_REGION" "${FALLBACK_REGIONS[@]}"; do
  if check_region_support "Microsoft.Web" "sites" "$region"; then
    APP_REGION="$region"
    pass "App Service: $region — supported"
    break
  else
    info "App Service: $region — not listed for this provider"
  fi
done
if [[ -z "$APP_REGION" ]]; then
  APP_REGION="centralus"
  warn "App Service: defaulting to centralus"
fi
PROFILE[appservice_location]="$APP_REGION"

info "Note: Provider location checks confirm global service support."
info "Subscription-specific restrictions (e.g., ProvisioningDisabled) can only"
info "be detected at deployment time. If deployment fails with a region error,"
info "update sql_location/appservice_location in subscription-profile.env."

###############################################################################
# 5. Generate Profile
###############################################################################
header "Generating Subscription Profile"

# --- .env format (primary — used by deploy scripts) ---
cat > "$PROFILE_ENV" << ENV
# =============================================================================
# AZ-305 Lab — Subscription Profile
# =============================================================================
# Generated by: prerequisites/profile-subscription.sh
# Date: $(date -u '+%Y-%m-%d %H:%M UTC')
# Subscription: ${SUBSCRIPTION_NAME} (${SUBSCRIPTION_ID})
#
# Source this file before running terraform, or use scripts/deploy-module.sh
# which sources it automatically. All detection used read-only APIs.
# Re-run the compatibility check if you change subscriptions.
# =============================================================================

# VM Configuration
export TF_VAR_vm_size="${PROFILE[vm_size]}"

# Regional Overrides (empty = use module default)
export TF_VAR_sql_location="${PROFILE[sql_location]}"
export TF_VAR_appservice_location="${PROFILE[appservice_location]}"

# Storage Policies
export TF_VAR_storage_shared_key_enabled="${PROFILE[storage_shared_key_enabled]}"
export TF_VAR_storage_public_network_access="${PROFILE[storage_public_network_access]}"
export TF_VAR_storage_allow_public_access="${PROFILE[storage_allow_public_access]}"

# Key Vault Policies
export TF_VAR_keyvault_public_network_access="${PROFILE[keyvault_public_network_access]}"

# Database Policies
export TF_VAR_sql_public_network_access="${PROFILE[sql_public_network_access]}"

# Data Factory Policies
export TF_VAR_data_factory_public_network="${PROFILE[data_factory_public_network]}"

# Authentication Policies (Event Hubs, Service Bus, API Management)
export TF_VAR_local_auth_enabled="${PROFILE[local_auth_enabled]}"
ENV

pass "Written: modules/subscription-profile.env"

# --- .tfvars format (reference — for manual terraform use) ---
cat > "$PROFILE_TFVARS" << TFVARS
# =============================================================================
# AZ-305 Lab — Subscription Profile (HCL format)
# =============================================================================
# Generated by: prerequisites/profile-subscription.sh
# Date: $(date -u '+%Y-%m-%d %H:%M UTC')
# Subscription: ${SUBSCRIPTION_NAME} (${SUBSCRIPTION_ID})
#
# Reference file. The deploy scripts use subscription-profile.env instead.
# To use this manually: terraform plan -var-file=../subscription-profile.tfvars
# =============================================================================

vm_size             = "${PROFILE[vm_size]}"
sql_location        = "${PROFILE[sql_location]}"
appservice_location = "${PROFILE[appservice_location]}"

storage_shared_key_enabled  = ${PROFILE[storage_shared_key_enabled]}
storage_public_network_access = ${PROFILE[storage_public_network_access]}
storage_allow_public_access = ${PROFILE[storage_allow_public_access]}

keyvault_public_network_access = ${PROFILE[keyvault_public_network_access]}

sql_public_network_access = ${PROFILE[sql_public_network_access]}

data_factory_public_network = ${PROFILE[data_factory_public_network]}

local_auth_enabled = ${PROFILE[local_auth_enabled]}
TFVARS

pass "Written: modules/subscription-profile.tfvars"

# Remove old auto.tfvars if it exists
if [[ -f "$LAB_ROOT/modules/subscription-profile.auto.tfvars" ]]; then
  rm -f "$LAB_ROOT/modules/subscription-profile.auto.tfvars"
  info "Removed old subscription-profile.auto.tfvars (replaced by .env format)"
fi

echo ""
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo -e "${BOLD}  Subscription Compatibility Check Complete${NC}"
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo -e "  VM Size:            ${GREEN}${PROFILE[vm_size]}${NC}"
echo -e "  SQL Region:         ${GREEN}${PROFILE[sql_location]}${NC}"
echo -e "  App Service Region: ${GREEN}${PROFILE[appservice_location]}${NC}"
echo -e "  Storage Keys:       $([ "${PROFILE[storage_shared_key_enabled]}" == "true" ] && echo "${GREEN}allowed${NC}" || echo "${YELLOW}disabled by policy${NC}")"
echo -e "  Storage Public Net: $([ "${PROFILE[storage_public_network_access]}" == "true" ] && echo "${GREEN}allowed${NC}" || echo "${YELLOW}disabled by policy${NC}")"
echo -e "  Public Blob Access: $([ "${PROFILE[storage_allow_public_access]}" == "true" ] && echo "${GREEN}allowed${NC}" || echo "${YELLOW}disabled by policy${NC}")"
echo -e "  Key Vault Public:   $([ "${PROFILE[keyvault_public_network_access]}" == "true" ] && echo "${GREEN}allowed${NC}" || echo "${YELLOW}disabled by policy${NC}")"
echo -e "  SQL Public Access:  $([ "${PROFILE[sql_public_network_access]}" == "true" ] && echo "${GREEN}allowed${NC}" || echo "${YELLOW}disabled by policy${NC}")"
echo -e "  Local Auth:         $([ "${PROFILE[local_auth_enabled]}" == "true" ] && echo "${GREEN}allowed${NC}" || echo "${YELLOW}disabled by policy${NC}")"
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Next: Run ./scripts/deploy-all.sh to deploy modules using these settings.${NC}"
