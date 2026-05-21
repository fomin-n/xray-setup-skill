#!/usr/bin/env bash
# Run LOCALLY. Tests SSH connectivity and basic server reachability.
# Usage: bash ssh_preflight.sh USER@HOST [PORT]
# Read-only — makes no changes on the server.

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok() { echo -e "  ${GREEN}[OK]${NC}  $1"; }
warn() { echo -e "  ${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "  ${RED}[FAIL]${NC} $1"; }

TARGET="${1:-}"
PORT="${2:-22}"

if [ -z "$TARGET" ]; then
  echo "Usage: $0 USER@HOST [PORT]"
  echo "Example: $0 root@203.0.113.50 22"
  exit 1
fi

echo "=== SSH Preflight: $TARGET (port $PORT) ==="

# 1 — TCP reachability
echo ""
echo "TCP reachability (port $PORT):"
if timeout 10 bash -c "cat < /dev/null > /dev/tcp/${TARGET#*@}/$PORT" 2>/dev/null; then
  ok "Port $PORT reachable"
else
  fail "Port $PORT not reachable on ${TARGET#*@}"
  echo "  Check: correct IP? firewall? VPS running?"
  exit 1
fi

# 2 — SSH handshake
echo ""
echo "SSH connectivity:"
SSH_OPTS="-p $PORT -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=accept-new"
if ssh $SSH_OPTS "$TARGET" 'echo SSH_OK' 2>/dev/null | grep -q SSH_OK; then
  ok "SSH key authentication works"
else
  fail "SSH key authentication failed"
  echo "  Check: correct user? key in ~/.ssh/authorized_keys on server?"
  echo "  Try manually: ssh -p $PORT $TARGET"
  exit 1
fi

# 3 — Remote OS detection
echo ""
echo "Remote OS:"
OS_INFO=$(ssh $SSH_OPTS "$TARGET" 'cat /etc/os-release 2>/dev/null | grep -E "^(NAME|VERSION_ID)=" | tr "\n" " "' 2>/dev/null)
if [ -n "$OS_INFO" ]; then
  ok "$OS_INFO"
else
  warn "Could not detect OS (non-standard distribution?)"
fi

# 4 — Remote privilege level
echo ""
echo "Privilege level:"
WHOAMI=$(ssh $SSH_OPTS "$TARGET" 'id -u' 2>/dev/null)
if [ "$WHOAMI" = "0" ]; then
  ok "Running as root (uid 0)"
elif ssh $SSH_OPTS "$TARGET" 'sudo -n true' 2>/dev/null; then
  ok "Non-root user with passwordless sudo"
else
  warn "Non-root user — passwordless sudo not confirmed; some steps may require sudo"
fi

# 5 — Key fingerprint (for user to verify)
echo ""
echo "Server host key fingerprint:"
ssh-keyscan -p "$PORT" -T 5 "${TARGET#*@}" 2>/dev/null | ssh-keygen -lf - 2>/dev/null | \
  awk '{print "  " $0}' || warn "Could not retrieve host key fingerprint"
echo ""
echo "  NOTE: StrictHostKeyChecking=accept-new was used above, so the host key"
echo "  was accepted automatically on first connect. If this is a new server,"
echo "  verify the fingerprint above matches what your VPS provider shows in"
echo "  its console (Hetzner: 'Remote Console', DigitalOcean: 'Access' tab)."

echo ""
echo "=== SSH preflight complete ==="
echo "SSH target confirmed: $TARGET -p $PORT"
