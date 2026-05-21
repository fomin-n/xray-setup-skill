# Angie Proxy (TLS Termination + HTTPS Fallback)

## What this file covers

Angie is used in the TLS path (Path B / C) to:
1. Terminate TLS on port 443
2. Distinguish VLESS traffic from regular HTTPS traffic
3. Forward VLESS connections to Xray via `proxy_protocol`
4. Serve a normal-looking HTTPS website for all other connections (camouflage)

For the REALITY path (Path A), Angie is not needed — skip this document.

## Angie vs nginx

Angie is a maintained fork of nginx (by the original nginx developers).
Its configuration syntax is identical to nginx. All examples below work for
both. Replace `angie` with `nginx` and the commands are the same.

---

## Install Angie (Ubuntu/Debian)

```bash
🌐 VPS
curl -o /tmp/angie-signing.gpg https://angie.software/keys/angie-signing.gpg
sudo mv /tmp/angie-signing.gpg /etc/apt/trusted.gpg.d/

echo "deb https://download.angie.software/angie/ubuntu/ $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/angie.list

sudo apt-get update
sudo apt-get install -y angie
sudo systemctl enable angie
```

If you prefer nginx:

```bash
🌐 VPS
sudo apt-get install -y nginx
sudo systemctl enable nginx
```

---

## TLS certificate

Certbot must issue the certificate before Angie can start with TLS.
See `xray-vless-tls.md` Step 4 for certbot setup.

If Angie is already on port 80, stop it temporarily for standalone certbot:

```bash
🌐 VPS
sudo systemctl stop angie
sudo certbot certonly --standalone -d <YOUR_DOMAIN>
sudo systemctl start angie
```

Or use certbot webroot plugin (Angie stays running):

```bash
🌐 VPS
sudo certbot certonly --webroot -w /var/www/html -d <YOUR_DOMAIN>
```

---

## Angie configuration

Replace `<YOUR_DOMAIN>` and `<CERT_PATH>` with your actual values.

Create `/etc/angie/http.d/xray.conf` (or `/etc/nginx/conf.d/xray.conf`):

```nginx
# HTTP → HTTPS redirect + ACME challenge path
server {
    listen 80;
    server_name <YOUR_DOMAIN>;

    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

# Main HTTPS server
server {
    listen 443 ssl reuseport;
    listen [::]:443 ssl reuseport;

    server_name <YOUR_DOMAIN>;

    ssl_certificate     /etc/letsencrypt/live/<YOUR_DOMAIN>/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/<YOUR_DOMAIN>/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305;
    ssl_prefer_server_ciphers off;

    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;
    ssl_session_tickets off;

    # HSTS (optional, enable after confirming everything works)
    # add_header Strict-Transport-Security "max-age=63072000" always;

    # Fallback: serve a normal-looking website
    root /var/www/html;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
```

**Alternative: stream block for proxy_protocol (recommended for VLESS+TLS)**

The stream approach works at the TCP level, before HTTP parsing, which is
more robust for VLESS. Edit `/etc/angie/angie.conf` to add a `stream` block:

```nginx
stream {
    map $ssl_preread_server_name $backend {
        <YOUR_DOMAIN>    127.0.0.1:11443;
        default          127.0.0.1:11444;  # fallback site backend
    }

    server {
        listen 443 reuseport;
        listen [::]:443 reuseport;

        ssl_preread on;
        proxy_pass $backend;
        proxy_protocol on;

        proxy_connect_timeout 10s;
        proxy_timeout 3600s;
    }
}
```

And keep the HTTP server above for the fallback site on port 11444
(a second Angie virtual server listening on 127.0.0.1:11444).

The stream approach sends the original client IP to Xray via proxy_protocol,
which requires `acceptProxyProtocol: true` in the Xray config.

---

## Fallback site content

Create a minimal but convincing fallback HTML page:

```bash
🌐 VPS
sudo mkdir -p /var/www/html
sudo tee /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><title>Welcome</title></head>
<body><h1>Welcome</h1><p>Service temporarily unavailable.</p></body>
</html>
EOF
```

The fallback site does not need to be elaborate — its purpose is to return
a 200 OK HTTPS response to anyone probing the port without a VLESS client.

---

## Test configuration

```bash
🌐 VPS
sudo angie -t     # or: sudo nginx -t
sudo systemctl reload angie
```

---

## Validate

```bash
🌐 VPS — paste output
bash scripts/check_ports.sh

🖥 LOCAL — paste output
bash scripts/check_tls.sh <YOUR_DOMAIN>
```

---

## cert auto-renewal hook

After certbot renews, reload Angie:

```bash
🌐 VPS
sudo tee /etc/letsencrypt/renewal-hooks/deploy/reload-angie.sh << 'EOF'
#!/bin/bash
systemctl reload angie
EOF
sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-angie.sh
```

---

## See also

- `xray-vless-tls.md` — Xray config that Angie proxies to
- `cloudflare.md` — if Cloudflare is in front of Angie
- `troubleshooting.md` — TLS cert errors, 502 from Angie
