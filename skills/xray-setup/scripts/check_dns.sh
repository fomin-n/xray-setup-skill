#!/usr/bin/env bash
# Run LOCALLY. Checks DNS resolution for a domain against an expected server IP.
# Usage: bash check_dns.sh <domain> <server-ip>
# Read-only — makes no changes.

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok() { echo -e "  ${GREEN}[OK]${NC}  $1"; }
warn() { echo -e "  ${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "  ${RED}[FAIL]${NC} $1"; }

DOMAIN="${1:-}"
EXPECTED_IP="${2:-}"

if [ -z "$DOMAIN" ]; then
  echo "Usage: $0 <domain> [expected-server-ip]"
  echo "Example: $0 example.com 1.2.3.4"
  exit 1
fi

echo "=== DNS Check for: $DOMAIN ==="

if ! command -v dig &>/dev/null && ! command -v nslookup &>/dev/null; then
  fail "Neither dig nor nslookup is available. Install dnsutils: sudo apt-get install dnsutils"
  exit 1
fi

echo ""
echo "A record resolution:"

if command -v dig &>/dev/null; then
  RESOLVED=$(dig +short A "$DOMAIN" 2>/dev/null | head -5)
else
  RESOLVED=$(nslookup "$DOMAIN" 2>/dev/null | awk '/^Address/ && !/#53/ {print $2}' | head -5)
fi

if [ -z "$RESOLVED" ]; then
  fail "No A record found for $DOMAIN"
else
  echo "  Resolved IPs:"
  echo "$RESOLVED" | while read -r ip; do
    echo "    $ip"
  done
fi

echo ""
if [ -n "$EXPECTED_IP" ]; then
  echo "Checking against expected IP: $EXPECTED_IP"
  if echo "$RESOLVED" | grep -q "^${EXPECTED_IP}$"; then
    ok "A record matches server IP ($EXPECTED_IP)"
  else
    fail "A record does NOT match server IP ($EXPECTED_IP)"
    echo "  DNS shows: $RESOLVED"
    echo "  Expected:  $EXPECTED_IP"
    echo ""
    warn "Possible causes:"
    echo "  - A record not created yet"
    echo "  - A record points to wrong IP"
    echo "  - Cloudflare is proxying (orange-cloud) — disable proxy to see real IP"
    echo "  - DNS propagation still in progress (wait 5–30 min, up to 48h)"
  fi
fi

echo ""
echo "TTL check:"
if command -v dig &>/dev/null; then
  TTL=$(dig +nocmd "$DOMAIN" A +noall +answer 2>/dev/null | awk '{print $2}' | head -1)
  if [ -n "$TTL" ]; then
    echo "  TTL: ${TTL}s"
    if [ "$TTL" -lt 300 ] 2>/dev/null; then
      warn "TTL is low (${TTL}s) — propagation should be fast"
    fi
  fi
fi

echo ""
echo "Cloudflare detection:"
if command -v dig &>/dev/null; then
  NS=$(dig +short NS "$DOMAIN" 2>/dev/null | head -3)
  if echo "$NS" | grep -qi "cloudflare"; then
    warn "Cloudflare nameservers detected for $DOMAIN"
    echo "  If orange-cloud (proxied): resolved IP will be a CF IP, not your server"
    echo "  Switch to grey-cloud (DNS-only) for direct TLS"
  else
    ok "No Cloudflare nameservers detected (direct DNS)"
  fi
fi

echo ""
echo "=== DNS check complete ==="
