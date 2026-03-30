#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# destroy-module.sh — Destroy a single AZ-305 lab module via Terraform
# Usage: ./scripts/destroy-module.sh [-y] [-c] <module-number-or-name>
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
CLEAN=false

usage() {
  echo -e "${BLUE}Usage:${NC} $0 [-y] [-c] <module-number-or-name>"
  echo ""
  echo "  module-number-or-name  e.g. 00, 05, foundation, ha-dr"
  echo "  -y                     Auto-approve (skip confirmation)"
  echo "  -c, --clean            Remove .terraform dir and state files after destroy"
  echo ""
  echo "Examples:"
  echo "  $0 03"
  echo "  $0 -y -c keyvault"
  exit 1
}

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

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes)
      AUTO_APPROVE=true
      shift
      ;;
    -c|--clean)
      CLEAN=true
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

echo -e "${RED}═══════════════════════════════════════════════════════════${NC}"
echo -e "${RED}  Destroying module: ${MODULE_DIR_NAME}${NC}"
echo -e "${RED}═══════════════════════════════════════════════════════════${NC}"

cd "$MODULE_PATH"

# Check for Terraform files
if ! ls *.tf &>/dev/null; then
  echo -e "${YELLOW}⚠ No Terraform files found in ${MODULE_DIR_NAME}. Nothing to destroy.${NC}"
  exit 0
fi

# Check for state — if no state, nothing to destroy
if [[ ! -f "terraform.tfstate" ]] && [[ ! -d ".terraform" ]]; then
  echo -e "${YELLOW}⚠ No Terraform state found for ${MODULE_DIR_NAME}. Nothing to destroy.${NC}"
  exit 0
fi

# Confirmation
if [[ "$AUTO_APPROVE" != "true" ]]; then
  echo ""
  echo -e "${RED}⚠  WARNING: This will DESTROY all resources in ${MODULE_DIR_NAME}${NC}"
  read -rp "  Type 'yes' to confirm destruction: " CONFIRM
  if [[ "$CONFIRM" != "yes" ]]; then
    echo -e "${YELLOW}⚠ Destruction cancelled.${NC}"
    exit 0
  fi
fi

# Ensure terraform is initialized
if [[ ! -d ".terraform" ]]; then
  echo -e "${BLUE}→ Running terraform init...${NC}"
  terraform init -input=false
fi

# Terraform destroy
echo -e "${RED}→ Running terraform destroy...${NC}"
if ! terraform destroy -auto-approve -input=false; then
  echo -e "${RED}✗ terraform destroy failed for ${MODULE_DIR_NAME}${NC}"
  exit 1
fi

echo -e "${GREEN}✓ Resources destroyed${NC}"

# Verify resources are gone
MODULE_NUMBER="${MODULE_DIR_NAME%%-*}"
echo -e "${BLUE}→ Verifying resources are removed...${NC}"
REMAINING=$(az resource list --tag "Module=${MODULE_NUMBER}" --query "[].name" -o tsv 2>/dev/null || true)
if [[ -n "$REMAINING" ]]; then
  echo -e "${YELLOW}⚠ Some resources may still exist:${NC}"
  echo "$REMAINING" | while read -r name; do
    echo -e "${YELLOW}  • $name${NC}"
  done
else
  echo -e "${GREEN}✓ No remaining resources found for module ${MODULE_NUMBER}${NC}"
fi

# Clean up if requested
if [[ "$CLEAN" == "true" ]]; then
  echo -e "${BLUE}→ Cleaning up local Terraform files...${NC}"
  rm -rf .terraform .terraform.lock.hcl
  rm -f terraform.tfstate terraform.tfstate.backup
  rm -f tfplan
  echo -e "${GREEN}✓ Local files cleaned${NC}"
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✓ Module ${MODULE_DIR_NAME} destroyed successfully${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
