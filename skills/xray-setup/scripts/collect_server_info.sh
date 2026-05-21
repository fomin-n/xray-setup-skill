#!/usr/bin/env bash
# Run on the VPS. Collects a snapshot of the server state for the setup assistant.
# Read-only — makes no changes.

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
section() { echo -e "\n${YELLOW}=== $1 ===${NC}"; }

section "OS / Kernel"
uname -a
lsb_release -a 2>/dev/null || cat /etc/os-release

section "Uptime / Load"
uptime

section "Current user"
id

section "Listening ports"
ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null || echo "ss/netstat not available"

section "Firewall (iptables INPUT)"
if command -v iptables &>/dev/null; then
  sudo iptables -L INPUT -n --line-numbers 2>/dev/null || echo "iptables not accessible"
else
  echo "iptables not installed"
fi

section "ufw status"
if command -v ufw &>/dev/null; then
  sudo ufw status verbose 2>/dev/null || echo "ufw not accessible"
else
  echo "ufw not installed"
fi

section "Docker"
if command -v docker &>/dev/null; then
  docker version --format 'Docker Engine {{.Server.Version}}' 2>/dev/null || echo "Docker daemon not running"
  echo "Running containers:"
  docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null || echo "Cannot list containers"
  echo "All containers:"
  docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}' 2>/dev/null
else
  echo "Docker not installed"
fi

section "Docker Compose"
if docker compose version &>/dev/null 2>&1; then
  docker compose version
elif command -v docker-compose &>/dev/null; then
  docker-compose --version
  echo "WARNING: docker-compose v1 detected. Skill uses v2 (docker compose)."
else
  echo "Docker Compose not installed"
fi

section "Existing Xray config"
for path in /etc/xray /opt/xray; do
  if [ -d "$path" ]; then
    echo "Found: $path"
    find "$path" -name "*.json" 2>/dev/null | head -10
  fi
done

section "Existing Marzban"
if [ -f /opt/marzban/.env ]; then
  echo "Marzban .env found at /opt/marzban/.env"
  echo "UVICORN_HOST setting:"
  grep -i UVICORN_HOST /opt/marzban/.env 2>/dev/null || echo "(not set)"
else
  echo "Marzban not found at /opt/marzban"
fi

section "Web servers"
for svc in nginx angie caddy apache2; do
  if systemctl is-active --quiet "$svc" 2>/dev/null; then
    echo -e "${GREEN}RUNNING${NC}: $svc"
  elif command -v "$svc" &>/dev/null; then
    echo -e "${YELLOW}INSTALLED but not running${NC}: $svc"
  fi
done

section "Disk space"
df -h / 2>/dev/null

section "Memory"
free -h 2>/dev/null

echo -e "\n${GREEN}=== collect_server_info complete ===${NC}"
echo "Paste this output to the setup assistant."
