#!/usr/bin/env bash
# Run on the VPS. Checks Marzban container state, port binding, and security posture.
# Read-only — makes no changes.

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok() { echo -e "  ${GREEN}[OK]${NC}  $1"; }
warn() { echo -e "  ${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "  ${RED}[FAIL]${NC} $1"; }

echo "=== Marzban Check ==="

MARZBAN_DIR="${1:-/opt/marzban}"
CONTAINER_NAME="${2:-marzban}"

echo ""
echo "Marzban directory: $MARZBAN_DIR"
if [ ! -d "$MARZBAN_DIR" ]; then
  warn "Marzban not found at $MARZBAN_DIR"
  echo "  Not installed — skip this check if Marzban is not needed."
  exit 0
fi
ok "Directory found"

echo ""
echo ".env file:"
ENV_FILE="$MARZBAN_DIR/.env"
if [ -f "$ENV_FILE" ]; then
  ok ".env exists"
  UVICORN_HOST=$(grep -i UVICORN_HOST "$ENV_FILE" | awk -F'=' '{print $2}' | tr -d ' "' | head -1)
  if [ "$UVICORN_HOST" = "127.0.0.1" ]; then
    ok "UVICORN_HOST = 127.0.0.1 (loopback — correct)"
  elif [ "$UVICORN_HOST" = "0.0.0.0" ]; then
    fail "UVICORN_HOST = 0.0.0.0 — Marzban is exposed to all interfaces!"
    echo "  Fix: edit $ENV_FILE, set UVICORN_HOST = \"127.0.0.1\", restart Marzban"
  else
    warn "UVICORN_HOST not set or unrecognized value: '$UVICORN_HOST'"
  fi
else
  warn ".env not found at $ENV_FILE"
fi

echo ""
echo "Container status:"
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
  ok "Container '$CONTAINER_NAME' is running"
  docker ps --filter "name=^${CONTAINER_NAME}$" --format \
    'Image: {{.Image}} | Status: {{.Status}} | Ports: {{.Ports}}'
else
  fail "Container '$CONTAINER_NAME' is NOT running"
  echo "  Start: cd $MARZBAN_DIR && docker compose up -d"
fi

echo ""
echo "Port 8000 binding (CRITICAL — must be loopback):"
PORT_LINE=$(ss -tlnp 2>/dev/null | grep ":8000 " | head -1)
if [ -z "$PORT_LINE" ]; then
  warn "Port 8000 not listening — Marzban may not be running"
elif echo "$PORT_LINE" | grep -qE "127\.|::1"; then
  ok "Port 8000 is bound to loopback only: $PORT_LINE"
else
  fail "Port 8000 is PUBLIC: $PORT_LINE"
  echo "  SECURITY ISSUE: Marzban dashboard is exposed to the internet!"
  echo "  Fix: set UVICORN_HOST = \"127.0.0.1\" in .env and restart Marzban"
fi

echo ""
echo "Port 8000 reachable from loopback:"
if curl -s --connect-timeout 3 http://127.0.0.1:8000/ &>/dev/null; then
  ok "Dashboard reachable at http://127.0.0.1:8000/ (via SSH tunnel to access)"
else
  warn "Dashboard not responding on 127.0.0.1:8000"
fi

echo ""
echo "Admin account check:"
docker exec "$CONTAINER_NAME" marzban-cli admin list 2>/dev/null && \
  ok "Admin list retrieved" || \
  warn "Cannot list admins (container may not be running)"

echo ""
echo "Recent Marzban logs (last 15 lines):"
docker logs "$CONTAINER_NAME" --tail 15 2>&1

echo ""
echo "=== Marzban check complete ==="
