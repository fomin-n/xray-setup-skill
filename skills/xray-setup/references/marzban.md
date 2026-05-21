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

Review it before running:

```bash
🌐 VPS
cat docker-compose.yml
```

### Step 3 — Create .env

```bash
🌐 VPS
sudo tee /opt/marzban/.env << 'EOF'
UVICORN_HOST = "127.0.0.1"
UVICORN_PORT = 8000
XRAY_JSON = "/var/lib/marzban/xray_config.json"
SQLALCHEMY_DATABASE_URL = "sqlite:////var/lib/marzban/db.sqlite3"
EOF
```

**Critical**: `UVICORN_HOST = "127.0.0.1"` — this binds Marzban to loopback
only. Never set this to `"0.0.0.0"` without a reverse proxy with authentication
in front.

Optional settings (add to `.env`):
- `TELEGRAM_API_TOKEN` — for Telegram bot notifications
- `TELEGRAM_ADMIN_ID` — Telegram admin chat ID
- `CUSTOM_TEMPLATES_DIRECTORY` — custom subscription templates
- `SUBSCRIPTION_URL_PREFIX` — custom subscription base URL

Do not paste the `.env` contents into chat.

### Step 4 — Pull and start

```bash
🌐 VPS
cd /opt/marzban
sudo docker compose pull
sudo docker compose up -d
```

### Step 5 — Initialize database

```bash
🌐 VPS
sudo docker compose exec marzban marzban-cli db init
```

### Step 6 — Create admin account

```bash
🌐 VPS
sudo docker compose exec -it marzban marzban-cli admin create --sudo
```

You will be prompted for a username and password. Use a strong password
(generated from `scripts/gen_credentials.sh`). This is the superadmin account.

Store credentials in your password manager immediately.

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
- Dashboard reachable via SSH tunnel

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
