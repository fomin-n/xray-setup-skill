# VLESS + REALITY Setup (no domain)

## When to use

Path A: Fresh VPS, no domain available. REALITY makes Xray look like a
legitimate TLS connection to a real website you specify in `serverNames`.
No certificate needed — Xray handles the TLS handshake internally.

## Prerequisites

- Docker installed (`references/docker.md`)
- Firewall open on port 443 (`references/firewall.md`)
- x25519 keypair generated (`references/secrets.md`)
- UUID generated for each user (`references/secrets.md`)

---

## Step 1 — Create directory structure

```bash
🌐 VPS
sudo mkdir -p /opt/xray/config
sudo mkdir -p /opt/xray/logs
```

---

## Step 2 — Generate credentials

```bash
🖥 LOCAL (or 🌐 VPS if Docker not available locally)
docker run --rm ghcr.io/xtls/xray-core x25519
```

Save private key and public key. Also generate a UUID and shortId:

```bash
🖥 LOCAL
uuidgen | tr '[:upper:]' '[:lower:]'   # → USER_UUID
openssl rand -hex 8                     # → SHORT_ID
```

---

## Step 3 — Write Xray config

Create `/opt/xray/config/config.json` on the VPS. Replace ALL `<PLACEHOLDER>`
values with your generated credentials before deploying.

```json
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log"
  },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "<USER_UUID>",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "www.microsoft.com:443",
          "xver": 0,
          "serverNames": [
            "www.microsoft.com"
          ],
          "privateKey": "<X25519_PRIVATE_KEY>",
          "shortIds": [
            "<SHORT_ID>"
          ]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "block"
    }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "type": "field",
        "ip": ["geoip:private"],
        "outboundTag": "block"
      }
    ]
  }
}
```

**Notes:**
- `dest`: The real website Xray will mirror for the TLS handshake. Choose
  a large, globally available domain (Microsoft, Apple, Cloudflare, etc.).
- `serverNames`: Must match the SNI your clients will send. Must include
  the domain you chose for `dest`.
- `privateKey`: Your x25519 private key (server-side, never shared).
- `shortIds`: Random hex strings, one per valid connection. Can have multiple.
- `flow: "xtls-rprx-vision"`: Required for REALITY with Vision padding.

---

## Step 4 — Write Docker Compose

Create `/opt/xray/docker-compose.yml`:

```yaml
services:
  xray:
    image: ghcr.io/xtls/xray-core:latest
    container_name: xray
    restart: unless-stopped
    ports:
      - "443:443"
    volumes:
      - ./config:/etc/xray
      - ./logs:/var/log/xray
    cap_add:
      - NET_ADMIN
```

---

## Step 5 — Start Xray

```bash
🌐 VPS
cd /opt/xray
docker compose up -d
docker compose logs -f --tail=20
```

Check for errors. A clean start shows no error lines in the log.

---

## Step 6 — Validate

```bash
🌐 VPS — paste output
bash scripts/check_xray.sh
```

Expected:
- Container `xray` is running
- Config parses without errors
- Port 443 is listening

---

## Client VLESS URI format

Construct the URI from your credentials:

```
vless://<USER_UUID>@<SERVER_IP>:443?security=reality&sni=www.microsoft.com&fp=chrome&pbk=<X25519_PUBLIC_KEY>&sid=<SHORT_ID>&flow=xtls-rprx-vision&type=tcp#MyServer
```

Parameters:
- `security=reality` — required
- `sni` — must match one of your `serverNames`
- `fp` — TLS fingerprint: `chrome`, `firefox`, `safari`, `ios`, `android`, `edge`, `random`
- `pbk` — x25519 **public** key (not the private key)
- `sid` — one of your `shortIds`
- `flow=xtls-rprx-vision` — required for Vision
- `type=tcp` — transport layer

See `client-setup.md` for how to import this URI on each platform.

---

## Adding more users

Add additional objects to the `clients` array in `config.json`, each with
a unique UUID. Reload Xray:

```bash
🌐 VPS
cd /opt/xray && docker compose restart xray
```

If using Marzban, users are managed through the panel instead of editing
`config.json` directly.

---

## See also

- `secrets.md` — credential generation
- `client-setup.md` — client import
- `marzban.md` — panel-based user management
- `troubleshooting.md` — common REALITY connection failures
