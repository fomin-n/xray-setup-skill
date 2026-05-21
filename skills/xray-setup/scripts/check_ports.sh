#!/usr/bin/env bash
# Run on the VPS. Shows which ports are listening and which processes own them.
# Read-only — makes no changes.

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok() { echo -e "  ${GREEN}[OK]${NC}  $1"; }
warn() { echo -e "  ${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "  ${RED}[FAIL]${NC} $1"; }

echo "=== Port Check ==="

echo ""
echo "All listening TCP ports:"
if command -v ss &>/dev/null; then
  ss -tlnp
elif command -v netstat &>/dev/null; then
  netstat -tlnp
else
  fail "Neither ss nor netstat available"
fi

echo ""
echo "Key port status:"

check_port() {
  local port="$1"
  local expected_bind="$2"  # "public", "loopback", or "closed"
  local description="$3"

  local line
  if command -v ss &>/dev/null; then
    line=$(ss -tlnp 2>/dev/null | grep ":${port} " | head -1)
  else
    line=$(netstat -tlnp 2>/dev/null | grep ":${port} " | head -1)
  fi

  if [ -z "$line" ]; then
    if [ "$expected_bind" = "closed" ]; then
      ok "Port $port: closed / not listening [$description]"
    else
      warn "Port $port: not listening — expected $expected_bind [$description]"
    fi
    return
  fi

  # Extract bind address
  local bind
  bind=$(echo "$line" | awk '{print $4}' | sed 's/:.*//')

  if echo "$bind" | grep -qE "^(127\.|::1)"; then
    if [ "$expected_bind" = "loopback" ]; then
      ok "Port $port: loopback-only ($bind) [$description]"
    elif [ "$expected_bind" = "public" ]; then
      warn "Port $port: loopback-only ($bind) — expected public [$description]"
    else
      ok "Port $port: loopback-only ($bind) [$description]"
    fi
  else
    if [ "$expected_bind" = "loopback" ]; then
      fail "Port $port: PUBLIC ($bind) — should be loopback-only! [$description]"
    else
      ok "Port $port: listening on $bind [$description]"
    fi
  fi
}

check_port 22   "public"   "SSH"
check_port 80   "public"   "HTTP / ACME challenge"
check_port 443  "public"   "VLESS / HTTPS"
check_port 8000 "loopback" "Marzban dashboard — MUST be loopback"
check_port 11443 "loopback" "Xray internal (TLS path)"

echo ""
echo "=== Port check complete ==="
echo "Paste this output to the setup assistant."
