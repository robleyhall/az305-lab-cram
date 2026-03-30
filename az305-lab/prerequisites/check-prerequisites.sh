#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# AZ-305 Lab — Prerequisite Checker
#
# Validates that all required tools, Azure login state, subscription access,
# role assignments, and provider registrations are in place before running labs.
###############################################################################

# ── Colours & symbols ────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Colour

PASS="${GREEN}✓${NC}"
FAIL="${RED}✗${NC}"
WARN="${YELLOW}⚠${NC}"

# ── Counters ─────────────────────────────────────────────────────────────────
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNED=0

pass()  { ((CHECKS_PASSED+=1)); echo -e "  ${PASS} $1"; }
fail()  { ((CHECKS_FAILED+=1)); echo -e "  ${FAIL} $1"; }
warn()  { ((CHECKS_WARNED+=1)); echo -e "  ${WARN} $1"; }
info()  { echo -e "  ${CYAN}ℹ${NC} $1"; }

header() { echo -e "\n${BOLD}── $1 ──${NC}"; }

# ── Semantic-version comparison ──────────────────────────────────────────────
# Returns 0 when $1 >= $2  (major.minor only)
version_gte() {
    local IFS=.
    local -a v1=($1) v2=($2)
    local maj1=${v1[0]:-0} min1=${v1[1]:-0}
    local maj2=${v2[0]:-0} min2=${v2[1]:-0}
    if (( maj1 > maj2 )); then return 0; fi
    if (( maj1 == maj2 && min1 >= min2 )); then return 0; fi
    return 1
}

###############################################################################
# 1. CLI Tools
###############################################################################
header "CLI Tools"

# ── Bash ─────────────────────────────────────────────────────────────────────
if command -v bash &>/dev/null; then
    bash_ver=$(bash --version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    pass "bash ${bash_ver}"
else
    fail "bash not found"
fi

# ── Git ──────────────────────────────────────────────────────────────────────
if command -v git &>/dev/null; then
    git_ver=$(git --version | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
    pass "git ${git_ver}"
else
    fail "git not found — install via your package manager or https://git-scm.com"
fi

# ── jq ───────────────────────────────────────────────────────────────────────
if command -v jq &>/dev/null; then
    jq_ver=$(jq --version 2>&1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
    pass "jq ${jq_ver}"
else
    fail "jq not found — install: brew install jq / sudo apt install jq"
fi

# ── Azure CLI (>= 2.50) ─────────────────────────────────────────────────────
AZ_MIN="2.50"
if command -v az &>/dev/null; then
    az_ver=$(az version --output json 2>/dev/null | jq -r '."azure-cli"' 2>/dev/null || az version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    if [[ -n "${az_ver}" ]] && version_gte "${az_ver}" "${AZ_MIN}"; then
        pass "Azure CLI ${az_ver} (>= ${AZ_MIN})"
    elif [[ -n "${az_ver}" ]]; then
        fail "Azure CLI ${az_ver} is below minimum ${AZ_MIN} — run: az upgrade"
    else
        fail "Azure CLI installed but unable to determine version"
    fi
else
    fail "Azure CLI not found — install: https://learn.microsoft.com/cli/azure/install-azure-cli"
fi

# ── Terraform (>= 1.5) ──────────────────────────────────────────────────────
TF_MIN="1.5"
if command -v terraform &>/dev/null; then
    tf_ver=$(terraform version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null || terraform version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    if [[ -n "${tf_ver}" ]] && version_gte "${tf_ver}" "${TF_MIN}"; then
        pass "Terraform ${tf_ver} (>= ${TF_MIN})"
    elif [[ -n "${tf_ver}" ]]; then
        fail "Terraform ${tf_ver} is below minimum ${TF_MIN} — upgrade: https://developer.hashicorp.com/terraform/install"
    else
        fail "Terraform installed but unable to determine version"
    fi
else
    fail "Terraform not found — install: https://developer.hashicorp.com/terraform/install"
fi

###############################################################################
# 2. Azure Login & Subscription
###############################################################################
header "Azure Authentication"

if ! command -v az &>/dev/null; then
    fail "Skipping Azure checks — Azure CLI not installed"
else
    # ── Logged in? ───────────────────────────────────────────────────────────
    if ACCOUNT_JSON=$(az account show --output json 2>/dev/null); then
        SUB_NAME=$(echo "${ACCOUNT_JSON}" | jq -r '.name')
        SUB_ID=$(echo "${ACCOUNT_JSON}" | jq -r '.id')
        SUB_STATE=$(echo "${ACCOUNT_JSON}" | jq -r '.state')
        TENANT_ID=$(echo "${ACCOUNT_JSON}" | jq -r '.tenantId')

        pass "Logged in to Azure"
        info "Subscription: ${SUB_NAME}"
        info "Subscription ID: ${SUB_ID}"
        info "Tenant ID: ${TENANT_ID}"

        # ── Subscription state ───────────────────────────────────────────────
        if [[ "${SUB_STATE}" == "Enabled" ]]; then
            pass "Subscription state: Enabled"
        else
            fail "Subscription state: ${SUB_STATE} — an Enabled subscription is required"
        fi

        # ── Subscription offer / type ────────────────────────────────────────
        # Best-effort: some subscriptions don't expose offerType
        if SUB_DETAIL=$(az account show --query '{offer: offerType, spendingLimit: spendingLimit}' --output json 2>/dev/null); then
            SPENDING=$(echo "${SUB_DETAIL}" | jq -r '.spendingLimit // empty')
            if [[ "${SPENDING}" == "On" ]]; then
                warn "Spending limit is ON — some resource deployments may fail. Consider a Pay-As-You-Go subscription."
            fi
        fi

        # ── Contributor role ─────────────────────────────────────────────────
        header "Role Assignment"
        SIGNED_IN_USER=$(az ad signed-in-user show --query id --output tsv 2>/dev/null || true)
        if [[ -n "${SIGNED_IN_USER}" ]]; then
            ROLE_MATCH=$(az role assignment list \
                --assignee "${SIGNED_IN_USER}" \
                --scope "/subscriptions/${SUB_ID}" \
                --query "[?roleDefinitionName=='Contributor' || roleDefinitionName=='Owner'].roleDefinitionName" \
                --output tsv 2>/dev/null || true)
            if [[ -n "${ROLE_MATCH}" ]]; then
                pass "Role: ${ROLE_MATCH%$'\n'*} on subscription"
            else
                fail "No Contributor/Owner role found on this subscription for the current user"
                info "Fix: az role assignment create --assignee \"${SIGNED_IN_USER}\" --role Contributor --scope /subscriptions/${SUB_ID}"
            fi
        else
            warn "Unable to determine signed-in user object ID (service principal login?) — skipping role check"
        fi

        # ── Provider Registrations ───────────────────────────────────────────
        header "Azure Provider Registrations"
        REQUIRED_PROVIDERS=(
            Microsoft.Compute
            Microsoft.Network
            Microsoft.Storage
            Microsoft.Sql
            Microsoft.DocumentDB
            Microsoft.Web
            Microsoft.KeyVault
            Microsoft.OperationalInsights
            Microsoft.EventGrid
            Microsoft.ServiceBus
            Microsoft.ApiManagement
            Microsoft.RecoveryServices
            Microsoft.DataFactory
        )

        # Fetch all registrations once for speed
        if REGISTERED_JSON=$(az provider list --query "[?registrationState=='Registered'].namespace" --output json 2>/dev/null); then
            for provider in "${REQUIRED_PROVIDERS[@]}"; do
                if echo "${REGISTERED_JSON}" | jq -e --arg p "${provider}" 'map(ascii_downcase) | index($p | ascii_downcase)' &>/dev/null; then
                    pass "${provider}"
                else
                    fail "${provider} is not registered"
                    info "Fix: az provider register --namespace ${provider}"
                fi
            done
        else
            fail "Unable to list provider registrations — ensure you are logged in and have access"
        fi

    else
        fail "Not logged in to Azure CLI"
        info "Fix: az login"
    fi
fi

###############################################################################
# Summary
###############################################################################
echo ""
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo -e "${BOLD}  Prerequisite Check Summary${NC}"
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo -e "  ${PASS} Passed:   ${CHECKS_PASSED}"
echo -e "  ${FAIL} Failed:   ${CHECKS_FAILED}"
echo -e "  ${WARN} Warnings: ${CHECKS_WARNED}"
echo -e "${BOLD}══════════════════════════════════════════${NC}"

if (( CHECKS_FAILED > 0 )); then
    echo -e "\n${RED}${BOLD}Some checks failed. Please resolve the issues above before proceeding.${NC}"
    exit 1
else
    echo -e "\n${GREEN}${BOLD}All critical checks passed. You are ready to run the labs!${NC}"
    exit 0
fi
