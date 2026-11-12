#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# destroy-all.sh — Destroy ALL AZ-305 lab modules in reverse order
# Usage: ./scripts/destroy-all.sh [-y] [-c]
###############################################################################

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

AUTO_APPROVE=false
CLEAN=false

MODULES=(12 11 10 09 08 07 06 05 04 03 02 01 00)
MODULE_NAMES=(
  "12-migration"
  "11-networking"
  "10-app-architecture"
  "09-compute"
  "08-data-integration"
  "07-databases"
  "06-storage"
  "05-ha-dr"
  "04-monitoring"
  "03-keyvault"
  "02-identity"
  "01-governance"
  "00-foundation"
)

declare -a DESTROYED=()
declare -a FAILED=()

usage() {
  echo -e "${BLUE}Usage:${NC} $0 [-y] [-c]"
  echo ""
  echo "  -y         Auto-approve (skip confirmation)"
  echo "  -c         Clean up .terraform and state files after destroy"
  exit 1
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
    *)
      echo -e "${RED}Unknown argument: $1${NC}"
      usage
      ;;
  esac
done

echo ""
echo -e "${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║                                                               ║${NC}"
echo -e "${RED}║   ⚠  WARNING: FULL LAB DESTRUCTION  ⚠                        ║${NC}"
echo -e "${RED}║                                                               ║${NC}"
echo -e "${RED}║   This will DESTROY ALL resources in ALL 13 modules.          ║${NC}"
echo -e "${RED}║   This action is IRREVERSIBLE.                                ║${NC}"
echo -e "${RED}║                                                               ║${NC}"
echo -e "${RED}║   Modules will be destroyed in reverse order:                 ║${NC}"
echo -e "${RED}║   12 → 11 → 10 → 09 → 08 → 07 → 06 → 05 →                  ║${NC}"
echo -e "${RED}║   04 → 03 → 02 → 01 → 00                                    ║${NC}"
echo -e "${RED}║                                                               ║${NC}"
echo -e "${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [[ "$AUTO_APPROVE" != "true" ]]; then
  echo -e "${RED}Type 'DESTROY ALL' to confirm complete lab destruction:${NC}"
  read -rp "  > " CONFIRM
  if [[ "$CONFIRM" != "DESTROY ALL" ]]; then
    echo -e "${YELLOW}⚠ Destruction cancelled.${NC}"
    exit 0
  fi
fi

TOTAL_START=$(date +%s)

for i in "${!MODULES[@]}"; do
  MODULE_NUM="${MODULES[$i]}"
  MODULE_NAME="${MODULE_NAMES[$i]}"

  echo -e "${RED}───────────────────────────────────────────────────────────────${NC}"
  echo -e "${RED}  Destroying: ${MODULE_NAME}${NC}"
  echo -e "${RED}───────────────────────────────────────────────────────────────${NC}"

  DESTROY_ARGS=("-y" "$MODULE_NUM")
  if [[ "$CLEAN" == "true" ]]; then
    DESTROY_ARGS=("-y" "-c" "$MODULE_NUM")
  fi

  if "$SCRIPT_DIR/destroy-module.sh" "${DESTROY_ARGS[@]}"; then
    DESTROYED+=("$MODULE_NAME")
    echo -e "${GREEN}✓ ${MODULE_NAME} — destroyed${NC}"
  else
    FAILED+=("$MODULE_NAME")
    echo -e "${RED}✗ ${MODULE_NAME} — FAILED (continuing...)${NC}"
  fi
  echo ""
done

TOTAL_END=$(date +%s)
TOTAL_ELAPSED=$((TOTAL_END - TOTAL_START))
TOTAL_MINUTES=$((TOTAL_ELAPSED / 60))
TOTAL_SECONDS=$((TOTAL_ELAPSED % 60))

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Destruction Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

if [[ ${#DESTROYED[@]} -gt 0 ]]; then
  echo -e "${GREEN}  ✓ Destroyed (${#DESTROYED[@]}):${NC}"
  for m in "${DESTROYED[@]}"; do
    echo -e "${GREEN}    • $m${NC}"
  done
fi

if [[ ${#FAILED[@]} -gt 0 ]]; then
  echo -e "${RED}  ✗ Failed (${#FAILED[@]}):${NC}"
  for m in "${FAILED[@]}"; do
    echo -e "${RED}    • $m${NC}"
  done
fi

echo ""
echo -e "${BLUE}  ⏱ Total time: ${TOTAL_MINUTES}m ${TOTAL_SECONDS}s${NC}"

# Final verification: check for remaining lab resource groups
echo ""
echo -e "${BLUE}→ Final verification: checking for remaining az305-lab-* resource groups...${NC}"
REMAINING_RGS=$(az group list --query "[?starts_with(name, 'az305-lab-')].name" -o tsv 2>/dev/null || true)

if [[ -n "$REMAINING_RGS" ]]; then
  echo -e "${YELLOW}⚠ The following az305-lab-* resource groups still exist:${NC}"
  echo "$REMAINING_RGS" | while read -r rg; do
    echo -e "${YELLOW}  • $rg${NC}"
  done
  echo -e "${YELLOW}  You may need to delete these manually:${NC}"
  echo -e "${YELLOW}  az group delete --name <name> --yes --no-wait${NC}"
else
  echo -e "${GREEN}✓ No az305-lab-* resource groups remaining. Lab fully cleaned up.${NC}"
fi

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

[[ ${#FAILED[@]} -gt 0 ]] && exit 1
exit 0
