# Overview: Architecture and Scenario Map

## What this skill sets up

```
Internet
    │
    ▼ :443
┌──────────────────────────────────────────────────────┐
│  VPS                                                  │
│                                                       │
│  ┌─────────┐   proxy_protocol   ┌────────────────┐   │
│  │  Angie  │ ─────────────────► │  Xray (Docker) │   │
│  │  :443   │  (TLS path only)   │  VLESS inbound │   │
│  └─────────┘                    └────────────────┘   │
│       │                                               │
│       │  HTTPS fallback (normal-looking website)      │
│                                                       │
│  ┌─────────────────────────────┐                      │
│  │  Marzban (Docker)           │  :8000 (loopback)   │
│  │  Management panel           │  ← NOT public        │
│  └─────────────────────────────┘                      │
│                                                       │
│  Firewall: INPUT DROP (allowlist: 22/80/443)         │
└──────────────────────────────────────────────────────┘
         ▲
         │  SSH tunnel (for Marzban dashboard)
         │
    User's machine
```

For the REALITY path (no domain), Angie is not used — Xray listens directly
on port 443 and handles TLS internally via REALITY.

## Component roles

| Component | Role | Exposed publicly |
|-----------|------|-----------------|
| Xray-core | VLESS proxy server | Port 443 only |
| Angie | TLS termination, HTTPS fallback (TLS path only) | Port 80, 443 |
| Marzban | User/subscription management panel | Never — loopback only |
| Docker | Container runtime for Xray and Marzban | No |
| iptables | Firewall — allowlist inbound | No |

## Scenario decision map

```
Is this a fresh VPS with no existing services?
├─ YES
│   Do you have a domain name pointed at this server?
│   ├─ NO  → Path A: VLESS + REALITY (no domain needed)
│   └─ YES
│       Is Cloudflare proxying the domain (orange cloud)?
│       ├─ NO  (grey cloud / DNS-only) → Path B: VLESS + TLS
│       └─ YES (proxied) → Path C: Cloudflare-specific setup
└─ NO (existing server)
    Does Xray already exist?
    ├─ YES, adding Marzban → Path E: Marzban only
    └─ NO / need migration → Path D: Conservative migration
```

See `decision-tree.md` for the full branching logic with questions.

## Port plan summary

| Scenario | Port 80 | Port 443 | Port 8000 |
|----------|---------|----------|-----------|
| REALITY (no domain) | Optional / closed | Xray direct | Loopback if Marzban |
| TLS + domain | Angie (cert renewal + redirect) | Angie → Xray | Loopback if Marzban |
| Cloudflare | Angie (CF origin cert) | Angie → Xray | Loopback if Marzban |

## Docker topology

All services run in Docker containers managed with Docker Compose.

```
docker compose (xray)
  xray:
    image: ghcr.io/xtls/xray-core
    ports: "443:443"
    volumes: ./config:/etc/xray

docker compose (marzban, if installed)
  marzban:
    image: gozargah/marzban
    ports: "127.0.0.1:8000:8000"   ← loopback binding only
    volumes: /opt/marzban:/var/lib/marzban
```

## Key file locations

| File | Purpose |
|------|---------|
| `/opt/xray/config/config.json` | Xray configuration |
| `/opt/xray/docker-compose.yml` | Xray Docker Compose |
| `/opt/marzban/.env` | Marzban environment config |
| `/opt/marzban/docker-compose.yml` | Marzban Docker Compose |
| `/etc/angie/` or `/etc/nginx/` | Angie/nginx config |
| `/etc/letsencrypt/` | TLS certificates |

## See also

- `decision-tree.md` — full scenario branching logic
- `ssh-hardening.md` — SSH posture before any other changes
- `firewall.md` — iptables setup
- `docker.md` — container runtime install
