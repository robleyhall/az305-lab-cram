#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# deploy-module.sh — Deploy a single AZ-305 lab module via Terraform
# Usage: ./scripts/deploy-module.sh [-y] <module-number-or-name>
###############################################################################

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MODULES_DIR="$LAB_ROOT/modules"

AUTO_APPROVE=false

usage() {
  echo -e "${BLUE}Usage:${NC} $0 [-y] <module-number-or-name>"
  echo ""
  echo "  module-number-or-name  e.g. 00, 05, foundation, ha-dr"
  echo "  -y                     Auto-approve (skip confirmation)"
  echo ""
  echo "Examples:"
  echo "  $0 00"
  echo "  $0 foundation"
  echo "  $0 -y 03"
  exit 1
}

# Map module name to directory prefix
declare -A MODULE_MAP=(
  [foundation]="00-foundation"
  [governance]="01-governance"
  [identity]="02-identity"
  [keyvault]="03-keyvault"
  [monitoring]="04-monitoring"
  [ha-dr]="05-ha-dr"
  [storage]="06-storage"
  [databases]="07-databases"
  [data-integration]="08-data-integration"
  [compute]="09-compute"
  [app-architecture]="10-app-architecture"
  [networking]="11-networking"
  [migration]="12-migration"
)

declare -A NUMBER_MAP=(
  [00]="00-foundation"
  [01]="01-governance"
  [02]="02-identity"
  [03]="03-keyvault"
  [04]="04-monitoring"
  [05]="05-ha-dr"
  [06]="06-storage"
  [07]="07-databases"
  [08]="08-data-integration"
  [09]="09-compute"
  [10]="10-app-architecture"
  [11]="11-networking"
  [12]="12-migration"
)

resolve_module() {
  local input="$1"
  if [[ -n "${NUMBER_MAP[$input]+x}" ]]; then
    echo "${NUMBER_MAP[$input]}"
  elif [[ -n "${MODULE_MAP[$input]+x}" ]]; then
    echo "${MODULE_MAP[$input]}"
  else
    # Try direct match against module directory names
    for dir in "$MODULES_DIR"/*/; do
      local dirname
      dirname="$(basename "$dir")"
      if [[ "$dirname" == *"$input"* ]]; then
        echo "$dirname"
        return
      fi
    done
    echo ""
  fi
}

# Parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes)
      AUTO_APPROVE=true
      shift
      ;;
    -h|--help)
      usage
      ;;
    -*)
      echo -e "${RED}Unknown flag: $1${NC}"
      usage
      ;;
    *)
      break
      ;;
  esac
done

[[ $# -lt 1 ]] && usage

MODULE_INPUT="$1"
MODULE_DIR_NAME="$(resolve_module "$MODULE_INPUT")"

if [[ -z "$MODULE_DIR_NAME" ]]; then
  echo -e "${RED}✗ Could not resolve module: ${MODULE_INPUT}${NC}"
  echo -e "${YELLOW}Available modules:${NC}"
  for num in 00 01 02 03 04 05 06 07 08 09 10 11 12; do
    echo "  $num → ${NUMBER_MAP[$num]}"
  done
  exit 1
fi

MODULE_PATH="$MODULES_DIR/$MODULE_DIR_NAME"

if [[ ! -d "$MODULE_PATH" ]]; then
  echo -e "${RED}✗ Module directory not found: ${MODULE_PATH}${NC}"
  exit 1
fi

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Deploying module: ${GREEN}${MODULE_DIR_NAME}${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

START_TIME=$(date +%s)
cd "$MODULE_PATH"

# Source subscription profile if available (sets TF_VAR_ environment variables)
PROFILE_ENV="${MODULES_DIR}/subscription-profile.env"
if [[ -f "$PROFILE_ENV" ]]; then
  # shellcheck source=/dev/null
  source "$PROFILE_ENV"
  echo -e "${GREEN}✓ Subscription profile loaded${NC}"
else
  echo -e "${YELLOW}⚠ No subscription profile found at modules/subscription-profile.env${NC}"
  echo -e "${YELLOW}  Run ./prerequisites/profile-subscription.sh first for policy-aware defaults.${NC}"
  echo -e "${YELLOW}  Continuing with module defaults...${NC}"
fi

# Check for Terraform files
if ! ls *.tf &>/dev/null; then
  echo -e "${YELLOW}⚠ No Terraform files found in ${MODULE_DIR_NAME}. Skipping.${NC}"
  exit 0
fi

# Terraform init (only if .terraform doesn't exist)
if [[ ! -d ".terraform" ]]; then
  echo -e "${BLUE}→ Running terraform init...${NC}"
  if ! terraform init -input=false; then
    echo -e "${RED}✗ terraform init failed for ${MODULE_DIR_NAME}${NC}"
    exit 1
  fi
  echo -e "${GREEN}✓ Terraform initialized${NC}"
else
  echo -e "${GREEN}✓ Terraform already initialized${NC}"
fi

# Terraform plan
echo -e "${BLUE}→ Running terraform plan...${NC}"
if ! terraform plan -out=tfplan -input=false; then
  echo -e "${RED}✗ terraform plan failed for ${MODULE_DIR_NAME}${NC}"
  exit 1
fi
echo -e "${GREEN}✓ Plan created${NC}"

# Confirmation
if [[ "$AUTO_APPROVE" != "true" ]]; then
  echo ""
  echo -e "${YELLOW}Review the plan above. Deploy ${MODULE_DIR_NAME}?${NC}"
  read -rp "  Type 'yes' to proceed: " CONFIRM
  if [[ "$CONFIRM" != "yes" ]]; then
    echo -e "${YELLOW}⚠ Deployment cancelled.${NC}"
    rm -f tfplan
    exit 0
  fi
fi

# Terraform apply
echo -e "${BLUE}→ Running terraform apply...${NC}"
if ! terraform apply tfplan; then
  echo -e "${RED}✗ terraform apply failed for ${MODULE_DIR_NAME}${NC}"
  rm -f tfplan
  exit 1
fi
rm -f tfplan

# Print outputs
echo ""
echo -e "${BLUE}→ Module outputs:${NC}"
terraform output 2>/dev/null || echo -e "${YELLOW}  (no outputs defined)${NC}"

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
MINUTES=$((ELAPSED / 60))
SECONDS=$((ELAPSED % 60))

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✓ Module ${MODULE_DIR_NAME} deployed successfully${NC}"
echo -e "${GREEN}  ⏱ Deployment time: ${MINUTES}m ${SECONDS}s${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
