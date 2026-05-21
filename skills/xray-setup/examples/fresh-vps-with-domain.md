# Example: Fresh VPS, Domain Available — VLESS + TLS

**Scenario:** Debian 12 VPS (DigitalOcean Droplet), freshly provisioned.
Domain `proxy.example.com` already pointing to server IP via Cloudflare DNS-only
(grey-cloud). User wants Marzban with SSH-tunnel dashboard access. Client: Windows.

---

## Phase 0 — Triage

> **User:** I have a new DigitalOcean droplet running Debian 12. I have a domain
> `proxy.example.com` that I've pointed to the server. It's on Cloudflare but I
> set it to DNS-only (the cloud is grey). I want Marzban too, but I don't want it
> publicly accessible. I'll use it on Windows.

Skill detects: **fresh** + **domain** + **Cloudflare DNS-only** = Path B.
Marzban requested, SSH-tunnel-only access.

---

## Phase 1 — Fact Collection

| Fact | Value |
|------|-------|
| VPS provider | DigitalOcean |
| Server IP | `198.51.100.20` |
| OS | Debian 12 |
| Root access | Yes |
| SSH port | 22 |
| SSH key | Pre-configured by DigitalOcean at provisioning |
| SSH password | Disabled by DigitalOcean (key-only) |
| Port 80/443/8000 | Nothing running |
| Domain | `proxy.example.com` |
| DNS pointing to server | Yes |
| Cloudflare | Yes, DNS-only (grey-cloud) |
| Marzban | Yes — SSH tunnel only |
| Client | Windows |

---

## Phase 2 — Safety Pre-flight

User opens second SSH session. Confirms.

Skill runs DNS check:

```bash
📋 PASTE OUTPUT: check_dns.sh proxy.example.com 198.51.100.20
=== DNS Check for: proxy.example.com ===
  Resolved IPs:
    198.51.100.20
  [OK]  A record matches server IP (198.51.100.20)
  TTL: 120s
  [WARN] Cloudflare nameservers detected for proxy.example.com
         If orange-cloud: resolved IP will be a CF IP, not your server
         Switch to grey-cloud (DNS-only) for direct TLS
```

DNS matches. CF nameservers detected but record is DNS-only — confirmed safe.

---

## Phase 3 — Scenario Routing

Skill confirms: **Path B — VLESS + TLS with domain**.

Plan:
- Certbot issues Let's Encrypt cert for `proxy.example.com`
- Angie: TLS terminator, HTTPS fallback, proxy_protocol to Xray
- Xray: loopback port 11443
- Marzban: loopback port 8000

---

## Phase 4 — SSH Hardening

DigitalOcean pre-configured key auth. `check_ssh.sh` output:

```
  [OK]  PubkeyAuthentication = yes
  [OK]  PasswordAuthentication = no
  [OK]  sshd is running
  [WARN] fail2ban not running
```

SSH gate confirmed. Skill notes fail2ban recommendation.

---

## Phase 5 — Firewall

Rules applied:
- 22 TCP IN (SSH)
- 80 TCP IN (ACME + redirect)
- 443 TCP IN (VLESS/HTTPS)

```
📋 PASTE OUTPUT: check_ports.sh
  [OK]  Port 22: listening
  [WARN] Port 80: not yet listening
  [WARN] Port 443: not yet listening
  [OK]  Port 8000: closed / not listening
```

---

## Phase 6 — Docker

Docker installed via apt repository. Verified running.

---

## Phase 8 — Angie + TLS (before Xray, to get cert first)

Angie installed. Port 80 opened temporarily for certbot standalone.

```bash
🌐 VPS
apt-get install -y certbot
systemctl stop angie
certbot certonly --standalone -d proxy.example.com
systemctl start angie
```

```
📋 PASTE OUTPUT: check_tls.sh proxy.example.com
=== TLS Certificate Check: proxy.example.com:443 ===
  Subject CN: proxy.example.com
  [OK]  CN matches domain
  [OK]  Domain found in SANs
  Expires: Jan 15 00:00:00 2027 GMT (89 days)
  [OK]  Certificate valid for 89 more days
  [OK]  Issued by Let's Encrypt
  [OK]  Certificate chain is valid
```

---

## Phase 7 — Xray TLS Setup

UUID generated locally. Config created at `/opt/xray/config/config.json`
with `listen: 127.0.0.1`, `port: 11443`, TLS cert paths mounted.

```
📋 PASTE OUTPUT: check_xray.sh
  [OK]  Container 'xray' is running
  [OK]  Xray config passes validation
  [OK]  Port 11443 is listening (loopback)
  [OK]  No errors in last 100 log lines
```

---

## Phase 9 — Marzban

Marzban installed via Docker Compose. `.env` set with `UVICORN_HOST = "127.0.0.1"`.
Admin created via CLI.

```
📋 PASTE OUTPUT: check_marzban.sh
  [OK]  .env exists
  [OK]  UVICORN_HOST = 127.0.0.1 (loopback — correct)
  [OK]  Container 'marzban' is running
  [OK]  Port 8000 is bound to loopback only
  [OK]  Dashboard reachable at http://127.0.0.1:8000/
```

**SSH tunnel to access dashboard:**

```bash
🖥 LOCAL
ssh -N -L 8000:127.0.0.1:8000 root@198.51.100.20
```

Browser: `http://localhost:8000/dashboard/` → Marzban login page.

---

## Phase 10 — Client Setup (Windows)

VLESS URI:

```
vless://a1b2c3d4-e5f6-7890-abcd-ef1234567890@proxy.example.com:443?security=tls&sni=proxy.example.com&fp=chrome&flow=xtls-rprx-vision&type=tcp#DigitalOcean-TLS
```

**v2rayN on Windows:**
1. Download v2rayN-With-Core.zip from GitHub
2. Run v2rayN.exe
3. Servers → Add server (VLESS) or Edit → Import bulk URL from clipboard
4. Tray icon → System proxy → Set system proxy

---

## Final security summary

| Port | Public? | Service |
|------|---------|---------|
| 22 | Yes | SSH (key-only) |
| 80 | Yes | HTTP → HTTPS redirect |
| 443 | Yes | Angie → Xray VLESS TLS |
| 8000 | No | Marzban (loopback, SSH tunnel) |
| 11443 | No | Xray internal (loopback) |
