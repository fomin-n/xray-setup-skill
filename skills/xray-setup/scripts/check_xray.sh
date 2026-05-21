#!/usr/bin/env bash
# Run on the VPS. Checks Xray container state, config validity, and port binding.
# Read-only — makes no changes.

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok() { echo -e "  ${GREEN}[OK]${NC}  $1"; }
warn() { echo -e "  ${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "  ${RED}[FAIL]${NC} $1"; }

echo "=== Xray Check ==="

XRAY_DIR="${1:-/opt/xray}"
CONTAINER_NAME="${2:-xray}"

echo ""
echo "Xray directory: $XRAY_DIR"
if [ ! -d "$XRAY_DIR" ]; then
  warn "Xray directory not found at $XRAY_DIR"
  echo "  Expected: /opt/xray"
else
  ok "Directory exists"
fi

echo ""
echo "Container status:"
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
  ok "Container '$CONTAINER_NAME' is running"
  docker ps --filter "name=^${CONTAINER_NAME}$" --format \
    'Image: {{.Image}} | Status: {{.Status}} | Ports: {{.Ports}}'
else
  fail "Container '$CONTAINER_NAME' is NOT running"
  echo "  Check all containers:"
  docker ps -a --format 'table {{.Names}}\t{{.Status}}' 2>/dev/null | head -20
  echo "  Start: cd $XRAY_DIR && docker compose up -d"
fi

echo ""
echo "Xray version:"
docker exec "$CONTAINER_NAME" xray version 2>/dev/null | head -3 || \
  warn "Cannot get Xray version (container may not be running)"

echo ""
echo "Config validation:"
CONFIG_FILE="$XRAY_DIR/config/config.json"
if [ -f "$CONFIG_FILE" ]; then
  ok "config.json found at $CONFIG_FILE"
  # Validate JSON syntax
  if python3 - "$CONFIG_FILE" <<'PYEOF' 2>/dev/null
import json, sys
json.load(open(sys.argv[1]))
PYEOF
  then
    ok "config.json is valid JSON"
  else
    fail "config.json has JSON syntax errors"
    python3 - "$CONFIG_FILE" <<'PYEOF' 2>&1
import json, sys
json.load(open(sys.argv[1]))
PYEOF
  fi
  # Test with Xray config validator
  docker exec "$CONTAINER_NAME" xray -test -c /etc/xray/config.json 2>&1 && \
    ok "Xray config passes validation" || \
    fail "Xray config validation failed"
else
  warn "config.json not found at $CONFIG_FILE"
fi

echo ""
echo "Port binding (443 and 11443):"
for port in 443 11443; do
  line=$(ss -tlnp 2>/dev/null | grep ":${port} " | head -1)
  if [ -n "$line" ]; then
    ok "Port $port is listening: $line"
  else
    warn "Port $port is NOT listening"
  fi
done

echo ""
echo "Recent Xray logs (last 20 lines):"
docker logs "$CONTAINER_NAME" --tail 20 2>&1 | grep -v "^$"

echo ""
echo "Xray error count (last 100 lines):"
ERROR_COUNT=$(docker logs "$CONTAINER_NAME" --tail 100 2>&1 | grep -c -i "error\|failed\|rejected" || true)
if [ "$ERROR_COUNT" -eq 0 ]; then
  ok "No errors in last 100 log lines"
else
  warn "$ERROR_COUNT error-related lines in last 100 log lines"
  echo "  Review: docker logs $CONTAINER_NAME --tail 100 | grep -i error"
fi

echo ""
echo "=== Xray check complete ==="
