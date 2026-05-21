# VLESS + TLS Setup (with domain)

## When to use

Path B: Fresh VPS, domain A record points directly at server IP, Cloudflare
is either not used or set to DNS-only (grey-cloud).

**Two variants:**

- **Standalone Xray** (this document): nginx handles TLS on port 443, passes
  VLESS traffic to Xray on loopback via `proxy_protocol`. Use when managing
  Xray without Marzban.

- **Marzban-managed Xray** (`references/marzban.md`): Xray handles TLS on
  port 443 directly (`network_mode: host`). nginx only on port 80 for certbot
  renewal and HTTP→HTTPS redirect. Use when you want the Marzban panel.

## Prerequisites (standalone path)

- Domain A record → server IP confirmed (`scripts/check_dns.sh`)
- Docker installed (`references/docker.md`)
- nginx installed (`references/angie-proxy.md`)
- Firewall open on 80 and 443 (`references/firewall.md`)
- UUID generated for each user (`references/secrets.md`)

---

## Architecture (standalone Xray — no Marzban)

```
Client → :443 → nginx (TLS termination) → proxy_protocol → Xray :11443
                       └→ HTTPS fallback site (non-VLESS traffic)
```

Xray does NOT listen on 443 directly. It listens on a loopback or internal
port (e.g., 11443), and nginx routes VLESS traffic to it.

For the Marzban architecture (Xray on 443 directly), see `marzban.md`.

---

## Step 1 — Create directory structure

```bash
🌐 VPS
sudo mkdir -p /opt/xray/config
sudo mkdir -p /opt/xray/logs
```

---

## Step 2 — Generate UUID

```bash
🖥 LOCAL
uuidgen | tr '[:upper:]' '[:lower:]'
```

Save as `USER_UUID`.

---

## Step 3 — Write Xray config

Create `/opt/xray/config/config.json`. Replace all `<PLACEHOLDER>` values.

```json
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log"
  },
  "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": 11443,
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
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "/etc/xray/certs/fullchain.pem",
              "keyFile": "/etc/xray/certs/privkey.pem"
            }
          ],
          "alpn": ["h2", "http/1.1"]
        },
        "sockopt": {
          "acceptProxyProtocol": true
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
- `listen: "127.0.0.1"` — Xray is NOT public; nginx proxies to it
- `port: 11443` — internal port; adjust if conflicting
- `acceptProxyProtocol: true` — required to receive real client IP from nginx
- `alpn: ["h2", "http/1.1"]` — h2 is fine here since nginx terminates TLS before sending to Xray; if you add `fallbacks` instead of proxy_protocol, drop "h2" (nginx 1.18 does not support h2c as a fallback backend)
- Cert files are mounted from the host where certbot writes them

---

## Step 4 — TLS certificate (Let's Encrypt via certbot)

Install certbot:

```bash
🌐 VPS
sudo apt-get install -y certbot
```

Obtain certificate (Angie must not be on port 80 yet, or use webroot):

```bash
🌐 VPS
sudo certbot certonly --standalone -d <YOUR_DOMAIN>
```

Certificates land in `/etc/letsencrypt/live/<YOUR_DOMAIN>/`.

Set up auto-renewal:

```bash
🌐 VPS
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer
```

---

## Step 5 — Link certs to Xray config volume

```bash
🌐 VPS
sudo mkdir -p /opt/xray/config/certs
sudo ln -sf /etc/letsencrypt/live/<YOUR_DOMAIN>/fullchain.pem \
            /opt/xray/config/certs/fullchain.pem
sudo ln -sf /etc/letsencrypt/live/<YOUR_DOMAIN>/privkey.pem \
            /opt/xray/config/certs/privkey.pem
```

---

## Step 6 — Write Docker Compose

Create `/opt/xray/docker-compose.yml`:

```yaml
services:
  xray:
    image: ghcr.io/xtls/xray-core:latest
    container_name: xray
    restart: unless-stopped
    ports:
      - "127.0.0.1:11443:11443"
    volumes:
      - ./config:/etc/xray
      - ./logs:/var/log/xray
```

Note: no `NET_ADMIN` needed since Xray is not on a public port.

---

## Step 7 — Configure Angie

See `angie-proxy.md` for the full Angie configuration that:
- listens on 443, terminates TLS
- sends VLESS traffic to `127.0.0.1:11443` with proxy_protocol
- serves an HTTPS fallback site for non-VLESS connections

---

## Step 8 — Start Xray

```bash
🌐 VPS
cd /opt/xray
docker compose up -d
docker compose logs -f --tail=20
```

---

## Step 9 — Validate

```bash
🌐 VPS — paste output
bash scripts/check_xray.sh
```

```bash
🖥 LOCAL — paste output
bash scripts/check_tls.sh <YOUR_DOMAIN>
```

Expected:
- Container running
- Config valid
- TLS cert valid, non-expired, CN matches domain

---

## Client VLESS URI format

```
vless://<USER_UUID>@<YOUR_DOMAIN>:443?security=tls&sni=<YOUR_DOMAIN>&fp=chrome&flow=xtls-rprx-vision&type=tcp#MyServer
```

Parameters:
- `security=tls`
- `sni` — your domain name
- `fp` — TLS fingerprint (chrome/firefox/safari/random)
- `flow=xtls-rprx-vision`
- `type=tcp`

See `client-setup.md` for platform-specific import steps.

---

## See also

- `angie-proxy.md` — TLS termination and fallback site
- `cloudflare.md` — if Cloudflare is involved
- `secrets.md` — credential generation
- `client-setup.md` — client import
- `troubleshooting.md` — TLS errors
