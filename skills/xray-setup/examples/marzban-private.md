# Example: Marzban with Private SSH-Tunnel Dashboard

**Scenario:** Xray REALITY already working on Ubuntu 22.04. User wants to add
Marzban for managing multiple users (family). Dashboard must not be public.

---

## Phase 0 — Triage

> **User:** I already have Xray VLESS REALITY running on my VPS. I want to add
> Marzban so I can manage users easily. I don't want the dashboard to be visible
> on the internet at all.

Skill detects: **marzban** scenario. Xray already present.

---

## Phase 2 — Pre-flight check

```bash
📋 PASTE OUTPUT: check_xray.sh
  [OK]  Container 'xray' is running
  [OK]  Xray config passes validation
  [OK]  Port 443 is listening
  [OK]  No errors in last 100 log lines
```

```bash
📋 PASTE OUTPUT: check_ports.sh
  [OK]  Port 22: listening
  [OK]  Port 443: listening
  [OK]  Port 8000: closed / not listening  ← good, Marzban not yet installed
```

---

## Phase 9 — Marzban Installation

Skill walks through the Docker method (not the one-liner script).

**Step 1: Review docker-compose.yml before running**

```bash
🌐 VPS
mkdir -p /opt/marzban && cd /opt/marzban
curl -o docker-compose.yml \
  https://raw.githubusercontent.com/Gozargah/Marzban/master/docker-compose.yml
cat docker-compose.yml   # review before running
```

User pastes the docker-compose.yml content for skill to review. Skill
confirms it looks standard (no unexpected ports or volumes).

**Step 2: Create .env**

```bash
🌐 VPS
tee /opt/marzban/.env << 'EOF'
UVICORN_HOST = "127.0.0.1"
UVICORN_PORT = 8000
XRAY_JSON = "/var/lib/marzban/xray_config.json"
SQLALCHEMY_DATABASE_URL = "sqlite:////var/lib/marzban/db.sqlite3"
EOF
```

**Step 3: Start Marzban**

```bash
🌐 VPS
docker compose pull
docker compose up -d
```

**Step 4: Initialize DB and create admin**

```bash
🌐 VPS
docker compose exec marzban marzban-cli db init

docker compose exec -it marzban marzban-cli admin create --sudo
# Prompted for username and password
# Use: username=myadmin, password=<generated 32-char password>
```

User stores credentials in password manager.

---

## Dashboard access via SSH tunnel

Skill explains:

> Your Marzban dashboard is now running at `127.0.0.1:8000` on the server.
> It is not publicly accessible. To use it, you create an SSH tunnel from
> your local machine.

**Open tunnel:**

```bash
🖥 LOCAL
ssh -N -L 8000:127.0.0.1:8000 root@<SERVER_IP>
```

Keep this terminal open while using the dashboard.

**Open in browser:** `http://localhost:8000/dashboard/`

Log in with the admin credentials you created.

**Shortcut (add to ~/.ssh/config):**

```
Host marzban
  HostName <SERVER_IP>
  User root
  IdentityFile ~/.ssh/vps_ed25519
  LocalForward 8000 127.0.0.1:8000
  ServerAliveInterval 60
```

Then: `ssh -N marzban`

---

## Validation

```bash
📋 PASTE OUTPUT: check_marzban.sh
  [OK]  .env exists
  [OK]  UVICORN_HOST = 127.0.0.1 (loopback — correct)
  [OK]  Container 'marzban' is running
  [OK]  Port 8000 is bound to loopback only
  [OK]  Dashboard reachable at http://127.0.0.1:8000/
```

**External test — confirm 8000 is not public:**

```bash
🖥 LOCAL (without tunnel active)
curl -v --connect-timeout 5 http://<SERVER_IP>:8000/
```

Expected: connection refused or timeout.

---

## Connecting Marzban to existing Xray

In Marzban dashboard (via tunnel):

1. Settings → Xray Configuration
2. Add inbound matching your existing VLESS REALITY config:
   - Type: VLESS
   - Port: 443
   - Address: same server IP
   - Security: reality
   - (fill in the same params as your existing `config.json`)
3. Save and apply

Marzban will now manage users for that inbound. Existing users from
`config.json` may need to be re-added via the Marzban UI.

---

## Security confirmation

| Port | Public? | Service |
|------|---------|---------|
| 22 | Yes | SSH (key-only) |
| 443 | Yes | Xray VLESS REALITY |
| 8000 | No | Marzban (loopback only) |
