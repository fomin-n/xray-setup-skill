# Dashboard Security (Marzban)

## Default: port 8000 is loopback-only

Marzban must bind to `127.0.0.1:8000`, not `0.0.0.0:8000`. This is enforced
via `UVICORN_HOST = "127.0.0.1"` in `/opt/marzban/.env`.

**Never** open port 8000 in the firewall. Verify with `scripts/check_marzban.sh`.

---

## Access method (a): SSH tunnel (most secure, recommended)

No server-side changes required beyond the loopback binding above.

On your local machine:

```bash
🖥 LOCAL
ssh -N -L 8000:127.0.0.1:8000 -p <SSH_PORT> <user>@<server-ip>
```

Then in your browser: `http://localhost:8000/dashboard/`

Keep the SSH tunnel running while using the dashboard. Close it when done.

For convenience, add to `~/.ssh/config`:

```
Host marzban-tunnel
  HostName <server-ip>
  User <user>
  Port <SSH_PORT>
  IdentityFile ~/.ssh/vps_ed25519
  LocalForward 8000 127.0.0.1:8000
  ServerAliveInterval 60
```

Then connect with: `ssh -N marzban-tunnel`

---

## Access method (b): Private HTTPS path via reverse proxy

If you want browser access without running an SSH tunnel, put Marzban behind
Angie/nginx with a randomized path prefix and Basic Auth or token.

This method requires a domain (TLS path B or C).

### Generate a random path prefix

```bash
🖥 LOCAL
openssl rand -hex 12
# example output: a3f8c1d9e2b547f6
```

### Angie config addition

In your existing Angie HTTPS server block, add:

```nginx
location /a3f8c1d9e2b547f6/ {
    proxy_pass http://127.0.0.1:8000/;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    # Optional: restrict to your own IP only
    # allow <YOUR_IP>;
    # deny all;
}
```

Dashboard URL: `https://<YOUR_DOMAIN>/a3f8c1d9e2b547f6/dashboard/`

Test Angie config and reload:

```bash
🌐 VPS
sudo angie -t && sudo systemctl reload angie
```

**Additional hardening:**

Add IP allowlist (`allow`/`deny`) to restrict access to your known IPs.
Or add HTTP Basic Auth:

```bash
🌐 VPS
sudo apt-get install -y apache2-utils
sudo htpasswd -c /etc/angie/.htpasswd <admin-user>
```

In the location block:

```nginx
auth_basic "Admin";
auth_basic_user_file /etc/angie/.htpasswd;
```

---

## Access method (c): Public HTTPS (not recommended)

If the user insists on public access, document the risks before proceeding:

- The dashboard login page is publicly accessible to the whole internet.
- Brute-force attacks on admin credentials are likely.
- Any Marzban vulnerability is directly exploitable.
- Marzban version history has had security issues.

Minimum mitigations required before enabling public access:
1. Strong admin password (32+ random characters)
2. IP allowlist in Angie if your IP is static
3. fail2ban rule for the dashboard path
4. Rate limiting in Angie

To enable (if user explicitly accepts risks): change `UVICORN_HOST` to
`"0.0.0.0"` in `.env` and open port 8000 in the firewall — but this is
strongly discouraged. The reverse proxy method above is preferred.

---

## Verify loopback binding

```bash
🌐 VPS
ss -tlnp | grep 8000
```

Expected: `127.0.0.1:8000` — not `0.0.0.0:8000`.

From the internet (local machine):

```bash
🖥 LOCAL
curl -v --connect-timeout 5 http://<server-ip>:8000/
```

Expected: connection refused or timeout (port closed to public).

---

## See also

- `marzban.md` — Marzban installation
- `angie-proxy.md` — Angie/nginx config
- `firewall.md` — confirm port 8000 is not in the public allowlist
