# Example: Existing Server Migration

**Scenario:** Ubuntu 20.04 VPS that already runs a website with nginx on port 443
(Let's Encrypt cert for `blog.example.com`). User wants to add VLESS without
breaking the website. Has Docker but no Xray yet.

---

## Phase 0 — Triage

> **User:** I have a VPS running Ubuntu 20.04 with nginx serving a blog on
> port 443. I have Docker installed. I want to add VLESS to this server
> without breaking my blog. I don't need Marzban.

Skill detects: **existing** scenario. Proceeds carefully.

---

## Phase 1 — Fact Collection

| Fact | Value |
|------|-------|
| Server IP | `203.0.113.75` |
| OS | Ubuntu 20.04 LTS |
| SSH key login | Yes |
| Password login | No |
| Port 443 | nginx (blog) |
| Port 80 | nginx (certbot) |
| Port 8000 | Nothing |
| Domain | `blog.example.com` (nginx) |
| Docker | Installed |
| Marzban | No |
| Client | iOS |

---

## Phase 2 — Safety Pre-flight

User opens second SSH session.

Skill asks user to run `collect_server_info.sh` and paste output:

```
📋 PASTE OUTPUT: collect_server_info.sh
=== Listening ports ===
tcp LISTEN  0.0.0.0:22    → sshd
tcp LISTEN  0.0.0.0:80    → nginx
tcp LISTEN  0.0.0.0:443   → nginx

=== Docker ===
Running containers: (none)
Docker Compose v2: yes

=== Web servers ===
RUNNING: nginx

=== Existing Xray config ===
Not found at /etc/xray or /opt/xray
```

**Conflict identified:** nginx occupies port 443. Xray cannot also bind :443.

---

## Phase 3 — Scenario Routing

Skill presents options:

**Option A (recommended):** Add Xray as a stream proxy behind nginx.
Nginx on 443 routes VLESS SNI to Xray internal port; all other traffic
serves the blog.

**Option B:** Move nginx to a different port (e.g., 8443), put Angie on 443
for Xray+TLS, proxy blog traffic to nginx:8443. More disruptive.

**Option C:** Use REALITY on a non-443 port (e.g., 8443), clients connect
to `203.0.113.75:8443`. Less stealthy but minimal disruption.

User chooses **Option A**.

---

## Migration Plan (Option A)

Skill explains the nginx stream module approach:

### Step 1 — Install nginx stream module

```bash
🌐 VPS
apt-get install -y libnginx-mod-stream
```

### Step 2 — Generate VLESS credentials

```bash
🖥 LOCAL
bash scripts/gen_credentials.sh
# Save UUID and x25519 keypair
```

### Step 3 — Add stream block to nginx

Backup first:

```bash
🌐 VPS
cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak.$(date +%Y%m%d)
```

Add stream block to `/etc/nginx/nginx.conf` (outside http block):

```nginx
stream {
    map $ssl_preread_server_name $backend {
        blog.example.com  127.0.0.1:11443;  # existing blog (nginx on 11443)
        ~.*               127.0.0.1:12443;  # VLESS Xray (on 12443)
    }
    server {
        listen 443 reuseport;
        ssl_preread on;
        proxy_pass $backend;
        proxy_protocol on;
    }
}
```

### Step 4 — Move nginx blog to internal port 11443

```bash
🌐 VPS
sed -i 's/listen 443 ssl/listen 127.0.0.1:11443 ssl proxy_protocol/' /etc/nginx/sites-enabled/blog.conf
nginx -t && systemctl reload nginx
```

Test blog still works before proceeding.

### Step 5 — Deploy Xray

Create `/opt/xray/config/config.json` with:
- `listen: "127.0.0.1"`, `port: 12443`
- VLESS + REALITY OR TLS (user's choice)
- `acceptProxyProtocol: true`

```bash
🌐 VPS
cd /opt/xray && docker compose up -d
```

### Step 6 — Validate

```bash
📋 PASTE OUTPUT: check_ports.sh
  [OK]  Port 22: listening
  [OK]  Port 80: listening (nginx)
  [OK]  Port 443: listening (nginx stream)
  [OK]  Port 8000: closed
  [OK]  Port 11443: loopback (nginx blog)
  [OK]  Port 12443: loopback (Xray)
```

Test blog: `curl -I https://blog.example.com` → 200 OK ✓

Test VLESS: iOS client (Streisand) connects, `ipinfo.io` shows VPS IP ✓

---

## Key lessons from this scenario

- Always run `collect_server_info.sh` first on existing servers
- Never overwrite an existing nginx config without a backup
- The stream module approach is additive — existing services are preserved
- Test the existing service after every config change before moving on
