# Troubleshooting Guide — Common Scenarios

Five annotated troubleshooting sessions. Each shows user symptoms,
diagnostic steps, and resolution.

---

## Scenario 1: Client connects but IP doesn't change (Android)

> **User:** My phone connects to the server (it shows "Connected") but when I
> check my IP on ipinfo.io it still shows my home IP.

**Skill response:** This is a client proxy mode issue, not a server issue.
Let's verify the server is actually routing traffic.

**Diagnostic:**

```bash
📋 PASTE OUTPUT: check_xray.sh
  [OK]  Container 'xray' is running
  [OK]  Xray config passes validation
  [OK]  Port 443 is listening
  [OK]  No errors in last 100 log lines
```

Server looks fine. Issue is on the client.

**Diagnosis:** Android NekoBox has two proxy modes:
- **Proxy** — only routes traffic from apps that use system proxy (many apps don't)
- **VPN** — routes all system traffic through a TUN device (what you want)

**Resolution:**

In NekoBox: long-press the profile → "Enable as System VPN" or select TUN
mode in the settings. Reconnect. Check `ipinfo.io` again.

---

## Scenario 2: TLS certificate error — "certificate verify failed"

> **User:** The Windows client (v2rayN) shows an error:
> "TLS handshake failed: certificate verify failed"

**Diagnostic:**

```bash
📋 PASTE OUTPUT: check_tls.sh proxy.example.com
=== TLS Certificate Check ===
  [FAIL] Could not connect to proxy.example.com:443
  Possible causes:
  - Port 443 not open in firewall
  - DNS not pointing to server
```

**Drill down:**

```bash
📋 PASTE OUTPUT: check_dns.sh proxy.example.com 198.51.100.20
  [FAIL] A record does NOT match server IP (198.51.100.20)
  DNS shows: 104.21.xx.xx
  The Cloudflare orange-cloud is proxying this domain!
```

**Root cause:** Cloudflare is proxying the domain (orange-cloud). The
resolved IP is a CF edge IP, not the server. Direct TLS from the Xray
client fails because CF is intercepting the connection.

**Resolution:**

1. Cloudflare dashboard → DNS → click orange cloud → turn grey (DNS-only)
2. Wait 1–5 minutes for propagation
3. Re-run `check_dns.sh` — should now show `198.51.100.20`
4. Retry client connection

---

## Scenario 3: REALITY connection rejected — "rejected by server"

> **User:** The iOS client (Streisand) gives "rejected" when connecting.
> Xray is running but nothing connects.

**Diagnostic:**

```bash
📋 PASTE OUTPUT (VPS)
docker logs xray --tail 50 | grep -i "error\|rejected\|reality"
```

```
rejected  11.22.33.44:12345  →  203.0.113.50:443
  reality: failed to verify shortId: f4a3b2c1d0e9f8a8
  expected one of: [f4a3b2c1d0e9f8a7]
```

**Root cause:** The `sid=` value in the client URI has the wrong shortId.
The client is sending `f4a3b2c1d0e9f8a8` (last digit `8`) but the server
expects `f4a3b2c1d0e9f8a7` (last digit `7`).

**Resolution:**

Check the client URI's `sid=` parameter. It should match one of the values
in the server's `realitySettings.shortIds[]` array. Correct the typo in the
URI, re-import into Streisand.

---

## Scenario 4: Marzban dashboard 502 Bad Gateway

> **User:** I opened the SSH tunnel, went to http://localhost:8000/dashboard/,
> but I'm getting a 502 Bad Gateway.

**Diagnostic:**

```bash
📋 PASTE OUTPUT: check_marzban.sh
  [OK]  .env exists
  [OK]  UVICORN_HOST = 127.0.0.1
  [FAIL] Container 'marzban' is NOT running
  Start: cd /opt/marzban && docker compose up -d
```

**Resolution:**

```bash
🌐 VPS
cd /opt/marzban
docker compose up -d
docker compose logs --tail 30
```

Logs show:

```
marzban  | ERROR: relation "users" does not exist
marzban  | HINT: Run: marzban-cli db init
```

**Root cause:** Database was never initialized.

```bash
🌐 VPS
docker compose exec marzban marzban-cli db init
docker compose restart
```

Dashboard loads after restart.

---

## Scenario 5: Docker pull fails — "manifest unknown"

> **User:** When I run docker compose up, I get:
> "Error response from daemon: manifest for ghcr.io/xtls/xray-core:latest
> not found: manifest unknown"

**Diagnostic:**

```bash
🌐 VPS
docker pull ghcr.io/xtls/xray-core:latest
```

```
Error response from daemon: unauthorized: authentication required
```

**Root cause:** GitHub Container Registry (ghcr.io) rate-limits unauthenticated
pulls. The server hit the limit.

**Resolution (Option A — authenticate):**

Create a GitHub personal access token (PAT) with `read:packages` scope:

```bash
🌐 VPS
echo "<YOUR_GITHUB_TOKEN>" | docker login ghcr.io -u <YOUR_GITHUB_USERNAME> --password-stdin
docker pull ghcr.io/xtls/xray-core:latest
```

**Resolution (Option B — use DockerHub mirror if available):**

Edit docker-compose.yml to use an alternative image. `teddysun/xray` is
community-maintained — verify its Dockerfile and provenance before use;
it has lower supply-chain assurance than the official `ghcr.io/xtls/xray-core`.

**Resolution (Option C — wait):**

GitHub rate limits reset hourly. Try again in 1 hour without authentication.
