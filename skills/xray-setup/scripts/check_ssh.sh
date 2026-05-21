#!/usr/bin/env bash
# Run on the VPS. Checks SSH hardening posture.
# Read-only — makes no changes.

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok() { echo -e "  ${GREEN}[OK]${NC}  $1"; }
warn() { echo -e "  ${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "  ${RED}[FAIL]${NC} $1"; }

echo "=== SSH Hardening Check ==="

SSHD_CONFIG="/etc/ssh/sshd_config"
if [ ! -f "$SSHD_CONFIG" ]; then
  fail "sshd_config not found at $SSHD_CONFIG"
  exit 1
fi

# Effective config (includes /etc/ssh/sshd_config.d/* if any)
EFFECTIVE=$(sshd -T 2>/dev/null || cat "$SSHD_CONFIG")

check_setting() {
  local key="$1"
  local expected="$2"
  local value
  value=$(echo "$EFFECTIVE" | grep -i "^${key}" | awk '{print tolower($2)}' | head -1)
  if [ "$value" = "$expected" ]; then
    ok "$key = $value"
  elif [ -z "$value" ]; then
    warn "$key not explicitly set (default may apply)"
  else
    fail "$key = $value (expected: $expected)"
  fi
}

check_setting "PubkeyAuthentication" "yes"
check_setting "PasswordAuthentication" "no"
check_setting "ChallengeResponseAuthentication" "no"
check_setting "PermitRootLogin" "no"  # warn only if not set to prohibit-password or no

echo ""
echo "SSH port:"
PORT=$(echo "$EFFECTIVE" | grep -i "^port " | awk '{print $2}' | head -1)
echo "  Port: ${PORT:-22 (default)}"

echo ""
echo "Authorized keys (current user):"
AK="$HOME/.ssh/authorized_keys"
if [ -f "$AK" ]; then
  COUNT=$(wc -l < "$AK")
  ok "authorized_keys exists ($COUNT key(s))"
  # Print key types without printing the full key
  awk '{print "  " $1}' "$AK"
else
  fail "authorized_keys not found at $AK"
fi

echo ""
echo "sshd service status:"
if systemctl is-active --quiet sshd 2>/dev/null || systemctl is-active --quiet ssh 2>/dev/null; then
  ok "sshd is running"
else
  fail "sshd is not running"
fi

echo ""
echo "fail2ban:"
if systemctl is-active --quiet fail2ban 2>/dev/null; then
  ok "fail2ban is active"
  sudo fail2ban-client status sshd 2>/dev/null | grep -E "Currently banned|Total banned" | sed 's/^/  /'
else
  warn "fail2ban is not running (recommended)"
fi

echo ""
echo "=== SSH check complete ==="
