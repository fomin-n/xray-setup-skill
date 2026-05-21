# Troubleshooting

## General approach

1. State symptoms clearly (error message, what happens vs what should happen)
2. Run the relevant diagnostic script and paste output
3. Match to a row in the symptom table below
4. Follow the resolution steps

Never suggest disabling the firewall as a diagnostic step — test specific
ports instead.

---

## Symptom table

### 1. Client cannot connect — connection refused on port 443

**Diagnostic:**
```bash
🌐 VPS
bash scripts/check_ports.sh
bash scripts/check_xray.sh
```

| Likely cause | Resolution |
|-------------|-----------|
| Xray container not running | `docker compose -f /opt/xray/docker-compose.yml up -d` |
| Xray config error prevents start | Check `docker compose logs xray` for JSON parse errors |
| Firewall blocking port 443 | `sudo iptables -L INPUT -n` — add port 443 rule |
| Angie not running (TLS path) | `sudo systemctl status angie` → start/fix |
| Angie not proxying to Xray | Check Angie config, verify `proxy_pass` to `127.0.0.1:11443` |

---

### 2. Client connects but traffic does not route (IP doesn't change)

**Diagnostic:**
```bash
🌐 VPS
docker exec xray xray -test -c /etc/xray/config.json
docker logs xray --tail 50
```

| Likely cause | Resolution |
|-------------|-----------|
| Client not in system proxy mode | Enable system proxy or TUN mode in client |
| Wrong outbound in Xray config | Verify outbound `freedom` is the default |
| DNS leak — client resolves locally | Enable DNS-over-Xray in client settings |
| `flow` mismatch | Client flow must match server flow (`xtls-rprx-vision`) |

---

### 3. TLS certificate error (TLS path)

**Diagnostic:**
```bash
🖥 LOCAL
bash scripts/check_tls.sh <YOUR_DOMAIN>
```

| Likely cause | Resolution |
|-------------|-----------|
| Cert not yet issued | Run certbot and check `/etc/letsencrypt/live/` |
| Cert expired | `sudo certbot renew --force-renewal` |
| CN mismatch (domain ≠ cert) | Reissue cert with correct domain |
| Cert not readable by Xray container | Check file permissions and volume mount |
| Angie serving wrong cert | Check `ssl_certificate` path in Angie config |

---

### 4. DNS not resolving / check_dns.sh fails

**Diagnostic:**
```bash
🖥 LOCAL
bash scripts/check_dns.sh <YOUR_DOMAIN> <SERVER_IP>
```

| Likely cause | Resolution |
|-------------|-----------|
| A record not created | Add A record in DNS provider dashboard |
| Record pointing to wrong IP | Update A record to server IP |
| DNS propagation in progress | Wait 5–30 minutes, re-run check |
| Cloudflare proxied, not grey | Switch to DNS-only in CF dashboard |
| TTL too high from old record | Wait for TTL to expire |

---

### 5. Docker container fails to start

**Diagnostic:**
```bash
🌐 VPS
docker compose -f /opt/xray/docker-compose.yml logs
```

| Likely cause | Resolution |
|-------------|-----------|
| Port already in use | `ss -tlnp | grep :443` — find and stop conflicting service |
| Config file JSON syntax error | Validate with `python3 -c "import json; json.load(open('config.json'))"` |
| Image pull failed | `docker pull ghcr.io/xtls/xray-core` — check network |
| Docker daemon not running | `sudo systemctl start docker` |
| Permission denied on volume | Check ownership of `/opt/xray/config/` |

---

### 6. REALITY connection failing

**Diagnostic:**
```bash
🌐 VPS
docker logs xray --tail 100 | grep -i "error\|reality\|rejected"
```

| Likely cause | Resolution |
|-------------|-----------|
| Wrong public key in client | Re-generate and check `pbk=` in URI matches server public key |
| `shortId` not in server config | Add the client's `sid` value to `shortIds` list |
| `sni` not in `serverNames` | Add matching SNI to server `serverNames` list |
| `serverNames` target unreachable from VPS | Test: `curl -I https://www.microsoft.com` from VPS |
| `flow` not set or mismatched | Both server and client must have `flow: xtls-rprx-vision` |
| Client fingerprint blocked | Try `fp=random` or a different fingerprint value |

---

### 7. Marzban dashboard not accessible via SSH tunnel

**Diagnostic:**
```bash
🌐 VPS
bash scripts/check_marzban.sh
```

| Likely cause | Resolution |
|-------------|-----------|
| SSH tunnel not established | Run: `ssh -N -L 8000:127.0.0.1:8000 <user>@<server>` |
| Marzban container not running | `docker compose -f /opt/marzban/docker-compose.yml up -d` |
| Wrong tunnel port | Verify tunnel is mapping local:8000 → remote:8000 |
| Browser cached redirect | Try `http://localhost:8000/dashboard/` (HTTP, not HTTPS) |

---

### 8. Marzban dashboard accessible from public internet (security incident)

```bash
🌐 VPS — immediate action
grep UVICORN_HOST /opt/marzban/.env
```

If `UVICORN_HOST = "0.0.0.0"`:

1. Stop Marzban: `docker compose -f /opt/marzban/docker-compose.yml stop`
2. Edit `.env`: change to `UVICORN_HOST = "127.0.0.1"`
3. Check firewall: `sudo iptables -D INPUT -p tcp --dport 8000 -j ACCEPT`
4. Start Marzban: `docker compose -f /opt/marzban/docker-compose.yml start`
5. Change admin password immediately
6. Review access logs for unauthorized logins

---

### 9. SSH locked out

See `rollback.md#ssh-lockout-recovery` for emergency console procedure.

---

### 10. Angie returns 502 Bad Gateway

```bash
🌐 VPS
sudo angie -t
sudo journalctl -u angie --since "5 minutes ago"
docker ps | grep xray
```

| Likely cause | Resolution |
|-------------|-----------|
| Xray not listening on upstream port | Start Xray; check port in Angie `proxy_pass` matches Xray listen port |
| proxy_protocol mismatch | Both Angie `proxy_protocol on` and Xray `acceptProxyProtocol: true` must be set |
| Permission denied on socket | Check Angie user has access to loopback |

---

### 11. Certificate auto-renewal failing

```bash
🌐 VPS
sudo certbot renew --dry-run
sudo systemctl status certbot.timer
```

| Likely cause | Resolution |
|-------------|-----------|
| Port 80 blocked | Allow port 80 for ACME challenge |
| Cloudflare proxied blocking challenge | Use DNS-01 challenge or disable proxy temporarily |
| Deploy hook not reloading Angie | Check `/etc/letsencrypt/renewal-hooks/deploy/` |

---

### 12. High latency / slow throughput

| Likely cause | Resolution |
|-------------|-----------|
| Server CPU overloaded | `top` on VPS — check if Xray or Docker is pegging CPU |
| Wrong transport (UDP-heavy apps) | VLESS/TCP is best for most traffic |
| VPS provider throttling | Test with iperf3 to/from server |
| WARP routing adding latency | Disable WARP and test directly |

---

### 13. `uuidgen` not available

```bash
🖥 LOCAL
python3 -c "import uuid; print(uuid.uuid4())"
```

---

### 14. Docker image pull rate limit

```bash
🌐 VPS
docker login ghcr.io
# Use a GitHub personal access token
```

Or pull during off-peak hours.

---

### 15. Client shows "invalid configuration"

Paste the VLESS URI into a URI parser:
- Check each query parameter is URL-encoded correctly
- `pbk` (public key) must be base64url (no `+` or `/` characters — use `-` and `_`)
- `sid` must be lowercase hex
- UUID must be lowercase with hyphens

---

## Log collection checklist

When filing a bug or asking for help, collect:

```bash
🌐 VPS
# Xray logs (last 100 lines, redacted — remove any UUIDs if sharing publicly)
docker logs xray --tail 100 2>&1 | sed 's/[0-9a-f-]\{36\}/UUID-REDACTED/g'

# Marzban logs (if installed)
docker logs marzban --tail 50 2>&1

# Port state
ss -tlnp

# Angie status
sudo systemctl status angie
```

## See also

- `rollback.md` — per-phase rollback
- `check_xray.sh`, `check_marzban.sh`, `check_tls.sh` — diagnostic scripts
