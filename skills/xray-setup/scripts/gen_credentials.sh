#!/usr/bin/env bash
# Run LOCALLY (preferred) or on the VPS if Docker is not available locally.
# Generates Xray credentials: x25519 keypair, UUID, shortId, random password.
#
# IMPORTANT: Save the output immediately to a password manager.
# Do NOT paste private keys or UUIDs back into the chat window.

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo "========================================"
echo "  Xray Credential Generator"
echo "========================================"
echo ""
echo -e "${YELLOW}IMPORTANT: Save this output to your password manager.${NC}"
echo -e "${YELLOW}Do NOT paste private keys or UUIDs into the chat.${NC}"
echo ""

# x25519 keypair (requires Docker or local xray binary)
echo "--- x25519 Keypair (for VLESS REALITY) ---"
if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
  X25519=$(docker run --rm ghcr.io/xtls/xray-core x25519 2>/dev/null)
  PRIVATE_KEY=$(echo "$X25519" | grep "Private key" | awk '{print $NF}')
  PUBLIC_KEY=$(echo "$X25519" | grep "Public key" | awk '{print $NF}')
  echo "Private key: $PRIVATE_KEY"
  echo "  ↑ SERVER ONLY — put in xray config.json realitySettings.privateKey"
  echo ""
  echo "Public key:  $PUBLIC_KEY"
  echo "  ↑ CLIENT — put in client URI as pbk= parameter"
elif command -v xray &>/dev/null; then
  xray x25519
  echo "  ↑ Private key → server config. Public key → client URI pbk="
else
  echo "Docker not available. Run this on a machine with Docker:"
  echo "  docker run --rm ghcr.io/xtls/xray-core x25519"
fi

echo ""
echo "--- VLESS User UUID ---"
if command -v uuidgen &>/dev/null; then
  UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')
elif command -v python3 &>/dev/null; then
  UUID=$(python3 -c "import uuid; print(uuid.uuid4())")
else
  echo "Cannot generate UUID — install uuidgen or python3"
  UUID=""
fi
if [ -n "$UUID" ]; then
  echo "UUID: $UUID"
  echo "  ↑ Put in xray config.json clients[].id AND client URI"
fi

echo ""
echo "--- REALITY shortId ---"
if command -v openssl &>/dev/null; then
  SHORT_ID=$(openssl rand -hex 8)
  echo "shortId: $SHORT_ID"
  echo "  ↑ Put in xray config.json realitySettings.shortIds[] AND client URI sid="
else
  echo "openssl not available — generate manually: 16 hex characters"
fi

echo ""
echo "--- Random strong password (Marzban admin / URL prefix) ---"
if command -v openssl &>/dev/null; then
  PASSWORD=$(openssl rand -base64 32 | tr -d '/+=' | head -c 32)
  echo "Password: $PASSWORD"
  echo "  ↑ Use for Marzban admin or random dashboard URL prefix"
else
  echo "openssl not available"
fi

echo ""
echo "========================================"
echo -e "${GREEN}Save all values above before closing this terminal.${NC}"
echo "========================================"
