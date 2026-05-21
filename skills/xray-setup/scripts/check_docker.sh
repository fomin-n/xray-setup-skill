#!/usr/bin/env bash
# Run on the VPS. Checks Docker installation and state.
# Read-only — makes no changes.

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok() { echo -e "  ${GREEN}[OK]${NC}  $1"; }
warn() { echo -e "  ${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "  ${RED}[FAIL]${NC} $1"; }

echo "=== Docker Check ==="

echo ""
echo "Docker installation:"
if ! command -v docker &>/dev/null; then
  fail "Docker not installed"
  echo "  Install: references/docker.md"
  exit 0
fi
ok "Docker binary found: $(which docker)"

echo ""
echo "Docker daemon:"
if docker info &>/dev/null 2>&1; then
  ok "Docker daemon is running"
  docker version --format 'Client: {{.Client.Version}} / Server: {{.Server.Version}}' 2>/dev/null
else
  fail "Docker daemon is NOT running"
  echo "  Fix: sudo systemctl start docker"
fi

echo ""
echo "Docker Compose:"
if docker compose version &>/dev/null 2>&1; then
  ok "$(docker compose version)"
elif command -v docker-compose &>/dev/null; then
  warn "docker-compose v1 found: $(docker-compose --version)"
  echo "  Upgrade to Compose v2: install docker-compose-plugin"
else
  warn "Docker Compose not installed"
fi

echo ""
echo "Current user docker access:"
if docker ps &>/dev/null 2>&1; then
  ok "User $(id -un) can run docker without sudo"
else
  warn "User $(id -un) cannot run docker without sudo"
  echo "  Fix: sudo usermod -aG docker \$USER && newgrp docker"
fi

echo ""
echo "Running containers:"
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null || \
  sudo docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null || \
  fail "Cannot list containers"

echo ""
echo "All containers (including stopped):"
docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}' 2>/dev/null

echo ""
echo "Docker system disk usage:"
docker system df 2>/dev/null

echo ""
echo "Docker enabled at boot:"
if systemctl is-enabled --quiet docker 2>/dev/null; then
  ok "Docker enabled at boot"
else
  warn "Docker NOT enabled at boot"
  echo "  Fix: sudo systemctl enable docker"
fi

echo ""
echo "=== Docker check complete ==="
