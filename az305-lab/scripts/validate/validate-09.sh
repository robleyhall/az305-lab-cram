#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# validate-09.sh — Validate Module 09: Compute
# Checks: VM running, web app responding, ACI running, function app deployed
###############################################################################

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

RG="az305-lab-compute"

check() {
  local description="$1"
  local result="$2"
  if [[ "$result" == "true" || "$result" == "0" ]]; then
    echo -e "  ${GREEN}✓ PASS${NC} — $description"
    ((PASS++))
  else
    echo -e "  ${RED}✗ FAIL${NC} — $description"
    ((FAIL++))
  fi
}

warn() {
  local description="$1"
  echo -e "  ${YELLOW}⚠ WARN${NC} — $description"
  ((WARN++))
}

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Validating Module 09: Compute${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Resource group
echo -e "${BLUE}→ Resource Group${NC}"
RG_EXISTS=$(az group exists --name "$RG" 2>/dev/null || echo "false")
check "Resource group '$RG' exists" "$RG_EXISTS"

if [[ "$RG_EXISTS" != "true" ]]; then
  echo -e "${RED}Resource group not found. Cannot continue validation.${NC}"
  echo -e "${RED}Results: ${PASS} passed, ${FAIL} failed, ${WARN} warnings${NC}"
  exit 1
fi

# Virtual Machine
echo -e "${BLUE}→ Virtual Machines${NC}"
VM_LIST=$(az vm list -g "$RG" --show-details --query "[].{name:name, state:powerState, size:hardwareProfile.vmSize}" -o json 2>/dev/null || echo "[]")
VM_COUNT=$(echo "$VM_LIST" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
check "VMs exist (found: $VM_COUNT)" "$([ "$VM_COUNT" -gt 0 ] && echo true || echo false)"

if [[ "$VM_COUNT" -gt 0 ]]; then
  RUNNING=$(echo "$VM_LIST" | python3 -c "import sys,json; print(len([v for v in json.load(sys.stdin) if v.get('state')=='VM running']))" 2>/dev/null || echo "0")
  check "VMs running ($RUNNING/$VM_COUNT)" "$([ "$RUNNING" -gt 0 ] && echo true || echo false)"

  echo "$VM_LIST" | python3 -c "
import sys, json
for v in json.load(sys.stdin):
    icon = '▶' if v.get('state') == 'VM running' else '⏸'
    print(f\"    {icon} {v['name']} — {v.get('state', 'unknown')} ({v.get('size', 'N/A')})\")
" 2>/dev/null
fi

# Web App
echo -e "${BLUE}→ Web Apps${NC}"
WEBAPP_LIST=$(az webapp list -g "$RG" --query "[].{name:name, state:state, url:defaultHostName}" -o json 2>/dev/null || echo "[]")
WEBAPP_COUNT=$(echo "$WEBAPP_LIST" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
check "Web apps exist (found: $WEBAPP_COUNT)" "$([ "$WEBAPP_COUNT" -gt 0 ] && echo true || echo false)"

if [[ "$WEBAPP_COUNT" -gt 0 ]]; then
  echo "$WEBAPP_LIST" | python3 -c "
import sys, json
for app in json.load(sys.stdin):
    print(f\"    • {app['name']} (state: {app.get('state', 'unknown')})\")
    print(f\"      URL: https://{app.get('url', 'N/A')}\")
" 2>/dev/null

  # Test if web app responds
  WEBAPP_URL=$(echo "$WEBAPP_LIST" | python3 -c "import sys,json; print(json.load(sys.stdin)[0].get('url',''))" 2>/dev/null)
  if [[ -n "$WEBAPP_URL" ]]; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://$WEBAPP_URL" --max-time 10 2>/dev/null || echo "000")
    check "Web app responding (HTTP: $HTTP_CODE)" "$([ "$HTTP_CODE" != "000" ] && [ "$HTTP_CODE" != "502" ] && [ "$HTTP_CODE" != "503" ] && echo true || echo false)"
  fi
fi

# Container Instances
echo -e "${BLUE}→ Container Instances${NC}"
ACI_LIST=$(az container list -g "$RG" --query "[].{name:name, state:provisioningState, status:containers[0].instanceView.currentState.state}" -o json 2>/dev/null || echo "[]")
ACI_COUNT=$(echo "$ACI_LIST" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

if [[ "$ACI_COUNT" -gt 0 ]]; then
  check "Container Instances exist (found: $ACI_COUNT)" "true"
  echo "$ACI_LIST" | python3 -c "
import sys, json
for c in json.load(sys.stdin):
    print(f\"    • {c['name']} (provisioning: {c.get('state', 'unknown')}, container: {c.get('status', 'unknown')})\")
" 2>/dev/null

  RUNNING_ACI=$(echo "$ACI_LIST" | python3 -c "import sys,json; print(len([c for c in json.load(sys.stdin) if c.get('status')=='Running' or c.get('state')=='Succeeded']))" 2>/dev/null || echo "0")
  check "Container Instances running ($RUNNING_ACI/$ACI_COUNT)" "$([ "$RUNNING_ACI" -gt 0 ] && echo true || echo false)"
else
  warn "No Container Instances found in $RG"
fi

# Function App
echo -e "${BLUE}→ Function Apps${NC}"
FUNC_LIST=$(az functionapp list -g "$RG" --query "[].{name:name, state:state, url:defaultHostName}" -o json 2>/dev/null || echo "[]")
FUNC_COUNT=$(echo "$FUNC_LIST" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

if [[ "$FUNC_COUNT" -gt 0 ]]; then
  check "Function Apps exist (found: $FUNC_COUNT)" "true"
  echo "$FUNC_LIST" | python3 -c "
import sys, json
for f in json.load(sys.stdin):
    print(f\"    • {f['name']} (state: {f.get('state', 'unknown')})\")
" 2>/dev/null

  # Check if function app is deployed
  FUNC_NAME=$(echo "$FUNC_LIST" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['name'])" 2>/dev/null)
  FUNC_URL=$(echo "$FUNC_LIST" | python3 -c "import sys,json; print(json.load(sys.stdin)[0].get('url',''))" 2>/dev/null)
  if [[ -n "$FUNC_URL" ]]; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://$FUNC_URL" --max-time 10 2>/dev/null || echo "000")
    check "Function App deployed and responding (HTTP: $HTTP_CODE)" "$([ "$HTTP_CODE" != "000" ] && echo true || echo false)"
  fi
else
  warn "No Function Apps found in $RG"
fi

# Summary
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "  Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}, ${YELLOW}${WARN} warnings${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

[[ $FAIL -gt 0 ]] && exit 1
exit 0
