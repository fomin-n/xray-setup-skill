# Cloudflare Configuration

## The core problem

Cloudflare proxied mode (orange-cloud) means:
- Cloudflare terminates TLS between the client and CF edge.
- CF re-establishes a separate TLS connection between CF and your VPS.
- Your server does NOT see the original client TLS handshake.

This breaks:
- **VLESS + REALITY** — requires direct TLS handshake to the server. Cannot
  work behind CF proxy. Hard stop.
- **Let's Encrypt ACME HTTP-01 challenge** — CF proxies port 80, which breaks
  standalone certbot. Use DNS-01 challenge or the webroot method instead.

---

## Path C decision

```
Cloudflare orange-cloud detected →

Option 1 (recommended): Switch to grey-cloud (DNS-only) → follow Path B
Option 2: Keep orange-cloud → use CF Origin Certificate + CF Full SSL
```

---

## Option 1: Switch to DNS-only (grey-cloud)

In Cloudflare dashboard → DNS → click the orange cloud icon next to your
A record → it turns grey → Save.

DNS propagation takes 1–5 minutes (Cloudflare TTL is short).

Verify with `scripts/check_dns.sh <domain> <server-ip>`. Then follow Path B.

**This is the strongly recommended path.** Proxied mode adds complexity
and breaks REALITY.

---

## Option 2: Cloudflare proxied with CF Origin Certificate

If you cannot or will not switch to DNS-only:

### Install CF Origin Certificate

1. Cloudflare dashboard → SSL/TLS → Origin Server → Create Certificate
2. Choose RSA or ECDSA, 15-year validity, list your domain(s)
3. Download: `origin.pem` (certificate) and `origin.key` (private key)
4. Upload to server:

```bash
🌐 VPS
sudo mkdir -p /etc/ssl/cloudflare
# Upload files via scp:
scp origin.pem origin.key <user>@<server-ip>:/etc/ssl/cloudflare/
sudo chmod 600 /etc/ssl/cloudflare/origin.key
```

### Configure Angie to use CF Origin Certificate

In your Angie config, replace Let's Encrypt cert paths:

```nginx
ssl_certificate     /etc/ssl/cloudflare/origin.pem;
ssl_certificate_key /etc/ssl/cloudflare/origin.key;
```

### Set Cloudflare SSL mode to "Full (strict)"

Cloudflare dashboard → SSL/TLS → Overview → Full (strict).

This makes CF validate your origin certificate (which it will, since
it issued the CF Origin Cert).

### Certbot: not needed in this case

CF Origin Certs don't expire for 15 years. No certbot renewal needed.

---

## CF IP ranges

If you want to restrict port 443 to CF edge IPs only (optional hardening):

```bash
🌐 VPS
# Cloudflare IPv4 ranges (check for updates at cloudflare.com/ips)
for ip in \
  173.245.48.0/20 103.21.244.0/22 103.22.200.0/22 103.31.4.0/22 \
  141.101.64.0/18 108.162.192.0/18 190.93.240.0/20 188.114.96.0/20 \
  197.234.240.0/22 198.41.128.0/17 162.158.0.0/15 104.16.0.0/13 \
  104.24.0.0/14 172.64.0.0/13 131.0.72.0/22; do
  sudo iptables -A INPUT -p tcp --dport 443 -s $ip -j ACCEPT
done
# Drop 443 from all other sources
sudo iptables -A INPUT -p tcp --dport 443 -j DROP
```

This means your VPS is only reachable on 443 via Cloudflare. Direct IP
access to port 443 is blocked (good for hiding your origin IP).

---

## Cloudflare + WARP (geo-restricted access)

If your server's IP is geo-restricted from certain websites (e.g., Russian
IP cannot reach some targets), you can route outbound VPS traffic through
Cloudflare WARP:

```bash
🌐 VPS
curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] \
  https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/cloudflare-client.list

sudo apt-get update && sudo apt-get install -y cloudflare-warp
warp-cli register
warp-cli set-mode proxy
warp-cli connect
```

Then configure Xray outbound to use the WARP SOCKS5 proxy (127.0.0.1:40000).

---

## See also

- `angie-proxy.md` — CF Origin Cert placement in Angie
- `xray-vless-tls.md` — Xray config for TLS path
- `decision-tree.md` — when to use CF paths
