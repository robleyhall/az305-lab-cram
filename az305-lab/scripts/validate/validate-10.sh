#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# validate-10.sh — Validate Module 10: App Architecture
# Checks: Event Grid, Event Hubs, Service Bus, Redis
###############################################################################

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

RG="az305-lab-app-architecture"

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
echo -e "${BLUE}  Validating Module 10: App Architecture${NC}"
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

# Event Grid Topic
echo -e "${BLUE}→ Event Grid${NC}"
EG_LIST=$(az eventgrid topic list -g "$RG" --query "[].{name:name, state:provisioningState}" -o json 2>/dev/null || echo "[]")
EG_COUNT=$(echo "$EG_LIST" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

if [[ "$EG_COUNT" -gt 0 ]]; then
  check "Event Grid topic exists (found: $EG_COUNT)" "true"
  EG_NAME=$(echo "$EG_LIST" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['name'])" 2>/dev/null)
  EG_STATE=$(echo "$EG_LIST" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['state'])" 2>/dev/null)
  check "Event Grid topic active (state: $EG_STATE)" "$([ "$EG_STATE" == "Succeeded" ] && echo true || echo false)"

  # Check subscriptions
  SUB_COUNT=$(az eventgrid event-subscription list --source-resource-id "$(az eventgrid topic show -g "$RG" -n "$EG_NAME" --query id -o tsv 2>/dev/null)" --query "length([])" -o tsv 2>/dev/null || echo "0")
  if [[ "$SUB_COUNT" -gt 0 ]]; then
    check "Event Grid subscriptions configured (found: $SUB_COUNT)" "true"
  else
    warn "No Event Grid subscriptions found"
  fi
else
  warn "No Event Grid topics found in $RG"
fi

# Event Hubs
echo -e "${BLUE}→ Event Hubs${NC}"
EH_NS=$(az eventhubs namespace list -g "$RG" --query "[].{name:name, state:provisioningState}" -o json 2>/dev/null || echo "[]")
EH_COUNT=$(echo "$EH_NS" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

if [[ "$EH_COUNT" -gt 0 ]]; then
  check "Event Hubs namespace exists (found: $EH_COUNT)" "true"
  NS_NAME=$(echo "$EH_NS" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['name'])" 2>/dev/null)
  NS_STATE=$(echo "$EH_NS" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['state'])" 2>/dev/null)
  check "Event Hubs namespace active (state: $NS_STATE)" "$([ "$NS_STATE" == "Succeeded" ] && echo true || echo false)"

  # Check event hubs in namespace
  HUB_COUNT=$(az eventhubs eventhub list -g "$RG" --namespace-name "$NS_NAME" --query "length([])" -o tsv 2>/dev/null || echo "0")
  check "Event hubs configured (found: $HUB_COUNT)" "$([ "$HUB_COUNT" -gt 0 ] && echo true || echo false)"
else
  warn "No Event Hubs namespaces found in $RG"
fi

# Service Bus
echo -e "${BLUE}→ Service Bus${NC}"
SB_NS=$(az servicebus namespace list -g "$RG" --query "[].{name:name, state:provisioningState}" -o json 2>/dev/null || echo "[]")
SB_COUNT=$(echo "$SB_NS" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

if [[ "$SB_COUNT" -gt 0 ]]; then
  check "Service Bus namespace exists (found: $SB_COUNT)" "true"
  SB_NAME=$(echo "$SB_NS" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['name'])" 2>/dev/null)
  SB_STATE=$(echo "$SB_NS" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['state'])" 2>/dev/null)
  check "Service Bus namespace active (state: $SB_STATE)" "$([ "$SB_STATE" == "Succeeded" ] && echo true || echo false)"

  # Queues
  QUEUE_COUNT=$(az servicebus queue list -g "$RG" --namespace-name "$SB_NAME" --query "length([])" -o tsv 2>/dev/null || echo "0")
  if [[ "$QUEUE_COUNT" -gt 0 ]]; then
    check "Service Bus queues configured (found: $QUEUE_COUNT)" "true"
  fi

  # Topics
  TOPIC_COUNT=$(az servicebus topic list -g "$RG" --namespace-name "$SB_NAME" --query "length([])" -o tsv 2>/dev/null || echo "0")
  if [[ "$TOPIC_COUNT" -gt 0 ]]; then
    check "Service Bus topics configured (found: $TOPIC_COUNT)" "true"
  fi
else
  warn "No Service Bus namespaces found in $RG"
fi

# Redis Cache
echo -e "${BLUE}→ Redis Cache${NC}"
REDIS_LIST=$(az redis list -g "$RG" --query "[].{name:name, state:provisioningState, sku:sku.name, port:sslPort}" -o json 2>/dev/null || echo "[]")
REDIS_COUNT=$(echo "$REDIS_LIST" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

if [[ "$REDIS_COUNT" -gt 0 ]]; then
  check "Redis Cache exists (found: $REDIS_COUNT)" "true"
  REDIS_NAME=$(echo "$REDIS_LIST" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['name'])" 2>/dev/null)
  REDIS_STATE=$(echo "$REDIS_LIST" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['state'])" 2>/dev/null)
  check "Redis Cache provisioned (state: $REDIS_STATE)" "$([ "$REDIS_STATE" == "Succeeded" ] && echo true || echo false)"

  # Check connectivity
  REDIS_HOST="${REDIS_NAME}.redis.cache.windows.net"
  REDIS_PORT=$(echo "$REDIS_LIST" | python3 -c "import sys,json; print(json.load(sys.stdin)[0].get('port', 6380))" 2>/dev/null)
  echo -e "  ${BLUE}  Host: $REDIS_HOST:$REDIS_PORT${NC}"
else
  warn "No Redis Cache found in $RG"
fi

# Summary
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "  Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}, ${YELLOW}${WARN} warnings${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

[[ $FAIL -gt 0 ]] && exit 1
exit 0
