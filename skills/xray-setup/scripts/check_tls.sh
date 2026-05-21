#!/usr/bin/env bash
# Run LOCALLY. Checks TLS certificate validity for a domain.
# Usage: bash check_tls.sh <domain> [port]
# Read-only — makes no changes.

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok() { echo -e "  ${GREEN}[OK]${NC}  $1"; }
warn() { echo -e "  ${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "  ${RED}[FAIL]${NC} $1"; }

DOMAIN="${1:-}"
PORT="${2:-443}"

if [ -z "$DOMAIN" ]; then
  echo "Usage: $0 <domain> [port]"
  echo "Example: $0 example.com 443"
  exit 1
fi

echo "=== TLS Certificate Check: $DOMAIN:$PORT ==="

if ! command -v openssl &>/dev/null; then
  fail "openssl not found. Install: sudo apt-get install openssl (or brew install openssl)"
  exit 1
fi

echo ""
echo "Fetching certificate..."
CERT_INFO=$(echo | timeout 10 openssl s_client \
  -connect "${DOMAIN}:${PORT}" \
  -servername "$DOMAIN" \
  -verify_quiet 2>/dev/null) || {
  fail "Could not connect to $DOMAIN:$PORT"
  echo "  Possible causes:"
  echo "  - Server not yet running"
  echo "  - Port $PORT not open in firewall"
  echo "  - DNS not pointing to server"
  exit 1
}

echo ""
echo "Certificate details:"
CERT=$(echo "$CERT_INFO" | openssl x509 -noout -text 2>/dev/null) || {
  fail "Could not parse certificate"
  exit 1
}

# Subject / CN
CN=$(echo "$CERT_INFO" | openssl x509 -noout -subject 2>/dev/null | sed 's/.*CN = //')
echo "  Subject CN: $CN"
if echo "$CN" | grep -q "$DOMAIN"; then
  ok "CN matches domain"
else
  warn "CN ($CN) does not exactly match $DOMAIN"
fi

# SANs
SANS=$(echo "$CERT_INFO" | openssl x509 -noout -ext subjectAltName 2>/dev/null | grep DNS | tr ',' '\n' | sed 's/DNS://g;s/ //g')
if [ -n "$SANS" ]; then
  echo "  SANs:"
  echo "$SANS" | while read -r san; do echo "    $san"; done
  if echo "$SANS" | grep -q "$DOMAIN"; then
    ok "Domain found in SANs"
  else
    warn "Domain not found in SANs"
  fi
fi

# Expiry
EXPIRY=$(echo "$CERT_INFO" | openssl x509 -noout -dates 2>/dev/null | grep notAfter | cut -d= -f2)
EXPIRY_EPOCH=$(date -d "$EXPIRY" +%s 2>/dev/null || date -j -f "%b %d %H:%M:%S %Y %Z" "$EXPIRY" +%s 2>/dev/null || echo "0")
NOW_EPOCH=$(date +%s)
DAYS_LEFT=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))

echo "  Expires: $EXPIRY ($DAYS_LEFT days)"
if [ "$DAYS_LEFT" -gt 30 ]; then
  ok "Certificate valid for $DAYS_LEFT more days"
elif [ "$DAYS_LEFT" -gt 0 ]; then
  warn "Certificate expires in $DAYS_LEFT days — consider renewal"
else
  fail "Certificate is EXPIRED"
fi

# Issuer
ISSUER=$(echo "$CERT_INFO" | openssl x509 -noout -issuer 2>/dev/null | sed 's/issuer= //')
echo "  Issuer: $ISSUER"
if echo "$ISSUER" | grep -qi "let's encrypt\|letsencrypt"; then
  ok "Issued by Let's Encrypt"
elif echo "$ISSUER" | grep -qi "cloudflare"; then
  ok "Issued by Cloudflare (CF Origin Certificate)"
else
  warn "Issuer: $ISSUER (not Let's Encrypt or Cloudflare)"
fi

echo ""
echo "Chain verification:"
if echo "$CERT_INFO" | grep -q "Verify return code: 0 (ok)"; then
  ok "Certificate chain is valid"
else
  VERIFY_CODE=$(echo "$CERT_INFO" | grep "Verify return code" | head -1)
  fail "Chain verification issue: $VERIFY_CODE"
fi

echo ""
echo "ALPN protocols:"
ALPN=$(echo "$CERT_INFO" | grep "ALPN protocol" | head -3)
if [ -n "$ALPN" ]; then
  echo "  $ALPN"
else
  warn "No ALPN advertised"
fi

echo ""
echo "=== TLS check complete ==="
