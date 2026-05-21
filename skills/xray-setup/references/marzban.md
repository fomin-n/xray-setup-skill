# Marzban Setup

## What Marzban does

Marzban is a web-based management panel for Xray. It provides:
- User/subscription management (create, revoke, set expiry, set traffic limits)
- Multiple inbound config management
- Subscription links for clients (auto-update configs)
- API for programmatic management

Marzban manages Xray. If Marzban is installed, it controls the Xray inbound
configuration — do not edit `config.json` directly after Marzban takes over.

---

## Prerequisites

- Xray working (Path A or B completed)
- Docker installed
- Port 8000 available on loopback (not publicly exposed)

---

## Installation method: Docker (recommended)

The official quick-install script (`sudo bash -c "$(curl ...)"`) is a
single pipeline that is hard to inspect. Use the manual Docker method instead.

### Step 1 — Prepare directory

```bash
🌐 VPS
sudo mkdir -p /opt/marzban
cd /opt/marzban
```

### Step 2 — Download the official docker-compose file

```bash
🌐 VPS
sudo curl -o docker-compose.yml \
  https://raw.githubusercontent.com/Gozargah/Marzban/master/docker-compose.yml
```

> This fetches from the `master` branch. For a reproducible, auditable setup
> pin to a specific release tag or commit SHA:
> `https://raw.githubusercontent.com/Gozargah/Marzban/v0.x.x/docker-compose.yml`

Review it before running:

```bash
🌐 VPS
cat docker-compose.yml
```

### Step 3 — Create .env

```bash
🌐 VPS
sudo mkdir -p /var/lib/marzban
sudo tee /opt/marzban/.env << 'EOF'
UVICORN_HOST = "127.0.0.1"
UVICORN_PORT = 8000
XRAY_JSON = "/var/lib/marzban/xray_config.json"
SQLALCHEMY_DATABASE_URL = "sqlite:////var/lib/marzban/db.sqlite3"
XRAY_SUBSCRIPTION_URL_PREFIX = "https://<YOUR_DOMAIN>"
EOF
```

**Critical**: `UVICORN_HOST = "127.0.0.1"` — this binds Marzban to loopback
only. Never set this to `"0.0.0.0"` without a reverse proxy with authentication
in front.

`SQLALCHEMY_DATABASE_URL` pointing to a host-mounted path is critical for
database persistence. Without it, Marzban uses `/code/db.sqlite3` inside
the container — which is wiped every time the container is recreated
(e.g., after `docker compose pull && docker compose up`).

Optional settings (add to `.env`):
- `TELEGRAM_API_TOKEN` — for Telegram bot notifications
- `TELEGRAM_ADMIN_ID` — Telegram admin chat ID
- `CUSTOM_TEMPLATES_DIRECTORY` — custom subscription templates

Do not paste the `.env` contents into chat.

### Step 4 — Pull and start

```bash
🌐 VPS
cd /opt/marzban
sudo docker compose pull
sudo docker compose up -d
```

### Step 5 — Create admin account

Admin creation requires an interactive TTY. Run this command directly in your
terminal (not via an automated script):

```bash
🌐 VPS (interactive terminal — run this yourself)
cd /opt/marzban && sudo docker compose exec -it marzban marzban-cli admin create --sudo
```

You will be prompted for username and password. Use a strong password from
`scripts/gen_credentials.sh`. Store credentials in your password manager
immediately — the password is never logged and cannot be recovered.

**Non-interactive alternative** (when running via SSH without a TTY):

```bash
🌐 VPS
# Generate a password locally first (bash scripts/gen_credentials.sh)
# Then pass it via MARZBAN_ADMIN_PASSWORD env var:
printf '\n\n' | sudo docker exec -i \
  -e MARZBAN_ADMIN_PASSWORD='<GENERATED_PASSWORD>' \
  marzban-marzban-1 marzban-cli admin create -u <USERNAME> --sudo
```

The `printf '\n\n'` provides Enter keypresses to skip optional interactive
prompts after username/password are set. Container name may vary — check with
`docker ps`.

> **Security note**: The `-e MARZBAN_ADMIN_PASSWORD=...` form passes the password
> via the environment and it is briefly visible in the process table (`ps aux`).
> On a single-user VPS this is acceptable. The password will also appear in your
> local shell history — clear it with `history -d $(history 1)` after running,
> or prefix the command with a space if your shell is configured to ignore
> space-prefixed commands.

---

## Dashboard URL

The Marzban dashboard is at `/dashboard/`, **not** the root `/`.

```
http://localhost:8000/dashboard/
```

Navigating to `http://localhost:8000/` shows an animated loading screen that
never resolves. This is expected — the API root is not the UI entrypoint.

---

## Marzban-managed Xray: direct TLS on port 443

When Marzban manages Xray, the recommended architecture is:
- Xray listens on port 443 directly (`network_mode: host`)
- TLS is handled inside Xray's config (`tlsSettings` with your cert)
- nginx handles only port 80 (certbot ACME renewal + HTTP→HTTPS redirect)
- Optionally: nginx on 127.0.0.1:8080 as an Xray fallback backend

This differs from the standalone Xray setup in `xray-vless-tls.md`, which
uses nginx as TLS terminator on 443 with proxy_protocol to Xray on 11443.

### Xray config template for Marzban (`/var/lib/marzban/xray_config.json`)

```json
{
  "log": {"loglevel": "warning"},
  "inbounds": [{
    "tag": "VLESS_TCP_TLS",
    "listen": "0.0.0.0",
    "port": 443,
    "protocol": "vless",
    "settings": {
      "clients": [],
      "decryption": "none",
      "fallbacks": [{"dest": 8080, "xver": 0}]
    },
    "streamSettings": {
      "network": "tcp",
      "security": "tls",
      "tlsSettings": {
        "alpn": ["http/1.1"],
        "certificates": [{
          "certificateFile": "/etc/letsencrypt/live/<YOUR_DOMAIN>/fullchain.pem",
          "keyFile": "/etc/letsencrypt/live/<YOUR_DOMAIN>/privkey.pem"
        }]
      }
    },
    "sniffing": {"enabled": true, "destOverride": ["http", "tls", "quic"]}
  }],
  "outbounds": [
    {"protocol": "freedom", "tag": "DIRECT"},
    {"protocol": "blackhole", "tag": "BLOCK"}
  ],
  "routing": {
    "rules": [{"ip": ["geoip:private"], "outboundTag": "BLOCK", "type": "field"}]
  }
}
```

Notes:
- `"clients": []` — Marzban fills this in dynamically; do not add users manually
- `"fallbacks"` — routes non-VLESS connections to nginx on 127.0.0.1:8080
- `"alpn": ["http/1.1"]` — h2 removed; nginx 1.18 does not support h2c for the fallback; VLESS clients are not ALPN-sensitive
- Cert path must be accessible from inside the container (mount `/etc/letsencrypt` read-only)

### docker-compose.yml for Marzban + cert access

```yaml
services:
  marzban:
    image: gozargah/marzban:latest  # pin to a version tag for reproducibility
    restart: always
    env_file: .env
    network_mode: host
    volumes:
      - /var/lib/marzban:/var/lib/marzban
      - /etc/letsencrypt:/etc/letsencrypt:ro
```

`network_mode: host` is needed because Xray must bind to `0.0.0.0:443` on
the host network. Port mapping (`ports:`) doesn't work with `0.0.0.0` binding.

---

## XTLS Vision flow default patch

Marzban's UI defaults to `flow: ""` (none) for new VLESS users. To default
to `xtls-rprx-vision`, patch the compiled dashboard JS bundle.

This requires extracting the current bundle from the running container,
patching it, and volume-mounting the patched file:

```bash
🌐 VPS
# 1. Find the JS bundle filename
sudo docker exec marzban-marzban-1 find /code/app/dashboard/build/statics/ -name 'index.*.js'

# 2. Copy bundle to host (adjust filename as found above)
sudo docker cp marzban-marzban-1:/code/app/dashboard/build/statics/index.<HASH>.js \
  /var/lib/marzban/index.<HASH>.js

# 3. Patch (one occurrence of vless:{id:"",flow:""} → vless:{id:"",flow:"xtls-rprx-vision"})
sudo python3 -c "
f='/var/lib/marzban/index.<HASH>.js'
d=open(f).read()
patched=d.replace('vless:{id:\"\",flow:\"\"}','vless:{id:\"\",flow:\"xtls-rprx-vision\"}',1)
assert patched != d, 'pattern not found'
open(f,'w').write(patched)
print('patched')
"

# 4. Add volume mount to docker-compose.yml
# Add this line under volumes:
#   - /var/lib/marzban/index.<HASH>.js:/code/app/dashboard/build/statics/index.<HASH>.js:ro

# 5. Restart to apply
sudo docker compose down && sudo docker compose up -d
```

**After `docker compose pull`**: the bundle is replaced and the patch must be
re-applied (repeat steps 1–3, then restart).

---

## Add Xray inbound in Marzban

After logging into the dashboard (via SSH tunnel — see `dashboard-security.md`):

1. Go to Settings → Xray Core
2. Add an inbound matching your Xray config (VLESS port, UUID, etc.)
3. Save and apply

Marzban will now write and manage the Xray config directly.

---

## Useful Marzban CLI commands

```bash
🌐 VPS
# Create additional admin
sudo docker compose -f /opt/marzban/docker-compose.yml exec -it marzban \
  marzban-cli admin create

# List admins
sudo docker compose -f /opt/marzban/docker-compose.yml exec marzban \
  marzban-cli admin list

# Reset admin password
sudo docker compose -f /opt/marzban/docker-compose.yml exec -it marzban \
  marzban-cli admin reset-password

# Restart
sudo docker compose -f /opt/marzban/docker-compose.yml restart
```

---

## Validate

```bash
🌐 VPS — paste output
bash scripts/check_marzban.sh
```

Expected:
- Container running
- Port 8000 bound to `127.0.0.1` only
- Admin account exists
- Dashboard reachable at `http://localhost:8000/dashboard/` via SSH tunnel

---

## Update Marzban

```bash
🌐 VPS
cd /opt/marzban
sudo docker compose pull
sudo docker compose up -d
```

---

## See also

- `dashboard-security.md` — how to access the dashboard safely
- `secrets.md` — generating a strong admin password
- `rollback.md#marzban-rollback` — stop and remove Marzban
