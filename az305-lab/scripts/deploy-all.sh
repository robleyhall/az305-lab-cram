#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# deploy-all.sh — Deploy all AZ-305 lab modules in order
# Usage: ./scripts/deploy-all.sh [-y] [--continue-on-error]
###############################################################################

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

AUTO_APPROVE=false
CONTINUE_ON_ERROR=false

MODULES=(00 01 02 03 04 05 06 07 08 09 10 11 12)
MODULE_NAMES=(
  "00-foundation"
  "01-governance"
  "02-identity"
  "03-keyvault"
  "04-monitoring"
  "05-ha-dr"
  "06-storage"
  "07-databases"
  "08-data-integration"
  "09-compute"
  "10-app-architecture"
  "11-networking"
  "12-migration"
)

declare -a SUCCEEDED=()
declare -a FAILED=()
declare -a SKIPPED=()

usage() {
  echo -e "${BLUE}Usage:${NC} $0 [-y] [--continue-on-error]"
  echo ""
  echo "  -y                   Auto-approve all modules (skip confirmation)"
  echo "  --continue-on-error  Continue deploying remaining modules if one fails"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes)
      AUTO_APPROVE=true
      shift
      ;;
    --continue-on-error)
      CONTINUE_ON_ERROR=true
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

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  AZ-305 Lab — Full Deployment${NC}"
echo -e "${BLUE}  Modules: ${#MODULES[@]} total${NC}"
echo -e "${BLUE}  Auto-approve: ${AUTO_APPROVE}${NC}"
echo -e "${BLUE}  Continue on error: ${CONTINUE_ON_ERROR}${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

TOTAL_START=$(date +%s)

for i in "${!MODULES[@]}"; do
  MODULE_NUM="${MODULES[$i]}"
  MODULE_NAME="${MODULE_NAMES[$i]}"

  echo -e "${BLUE}───────────────────────────────────────────────────────────────${NC}"
  echo -e "${BLUE}  [${MODULE_NUM}/${MODULES[-1]}] Deploying: ${MODULE_NAME}${NC}"
  echo -e "${BLUE}───────────────────────────────────────────────────────────────${NC}"

  DEPLOY_ARGS=("$MODULE_NUM")
  if [[ "$AUTO_APPROVE" == "true" ]]; then
    DEPLOY_ARGS=("-y" "$MODULE_NUM")
  fi

  if "$SCRIPT_DIR/deploy-module.sh" "${DEPLOY_ARGS[@]}"; then
    SUCCEEDED+=("$MODULE_NAME")
    echo -e "${GREEN}✓ ${MODULE_NAME} — success${NC}"
  else
    FAILED+=("$MODULE_NAME")
    echo -e "${RED}✗ ${MODULE_NAME} — FAILED${NC}"

    if [[ "$CONTINUE_ON_ERROR" != "true" ]]; then
      echo -e "${RED}Stopping deployment. Use --continue-on-error to proceed past failures.${NC}"
      # Mark remaining as skipped
      for j in $(seq $((i + 1)) $((${#MODULES[@]} - 1))); do
        SKIPPED+=("${MODULE_NAMES[$j]}")
      done
      break
    fi
  fi
  echo ""
done

TOTAL_END=$(date +%s)
TOTAL_ELAPSED=$((TOTAL_END - TOTAL_START))
TOTAL_MINUTES=$((TOTAL_ELAPSED / 60))
TOTAL_SECONDS=$((TOTAL_ELAPSED % 60))

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Deployment Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

if [[ ${#SUCCEEDED[@]} -gt 0 ]]; then
  echo -e "${GREEN}  ✓ Succeeded (${#SUCCEEDED[@]}):${NC}"
  for m in "${SUCCEEDED[@]}"; do
    echo -e "${GREEN}    • $m${NC}"
  done
fi

if [[ ${#FAILED[@]} -gt 0 ]]; then
  echo -e "${RED}  ✗ Failed (${#FAILED[@]}):${NC}"
  for m in "${FAILED[@]}"; do
    echo -e "${RED}    • $m${NC}"
  done
fi

if [[ ${#SKIPPED[@]} -gt 0 ]]; then
  echo -e "${YELLOW}  ⊘ Skipped (${#SKIPPED[@]}):${NC}"
  for m in "${SKIPPED[@]}"; do
    echo -e "${YELLOW}    • $m${NC}"
  done
fi

echo ""
echo -e "${BLUE}  ⏱ Total time: ${TOTAL_MINUTES}m ${TOTAL_SECONDS}s${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

[[ ${#FAILED[@]} -gt 0 ]] && exit 1
exit 0
