# Secrets Generation

## Rules

1. Generate all credentials locally (🖥 LOCAL) unless the command requires
   Docker which may not be installed locally — in that case run on VPS and
   **do not log the output** beyond copying it immediately.
2. Never paste private keys, UUIDs, or `.env` values back into the chat.
3. Store everything in a password manager before the session ends.
4. If a secret is lost: regenerate and update configs + clients.

---

## x25519 keypair (REALITY)

Requires Docker (or a local Xray binary):

```bash
🖥 LOCAL (if Docker is installed locally)
docker run --rm ghcr.io/xtls/xray-core x25519
```

```bash
🌐 VPS (if Docker is only on the server)
docker run --rm ghcr.io/xtls/xray-core x25519
```

Output:

```
Private key: <base64-encoded-private-key>
Public key:  <base64-encoded-public-key>
```

- **Private key** → goes into the Xray `inbounds[].streamSettings.realitySettings.privateKey` on the server. Keep it secret.
- **Public key** → goes into the client config. Safe to share with your own clients.

---

## VLESS user UUID

```bash
🖥 LOCAL
uuidgen | tr '[:upper:]' '[:lower:]'
```

Or using Python (available on most systems):

```bash
🖥 LOCAL
python3 -c "import uuid; print(uuid.uuid4())"
```

This UUID identifies a user in the VLESS inbound config. Each user gets a
unique UUID. Do not reuse UUIDs across different servers.

---

## REALITY shortId

A random 8–16 character hex string:

```bash
🖥 LOCAL
openssl rand -hex 8
```

The `shortId` is an additional validation value for REALITY connections. Use
a different value for each server/inbound.

---

## Random strong password (Marzban admin, path prefix)

```bash
🖥 LOCAL
openssl rand -base64 32 | tr -d '/+=' | head -c 32
```

Use for:
- Marzban admin password (set via `marzban cli admin create`)
- Random URL path prefix for Marzban dashboard if using private HTTPS path

---

## ED25519 SSH keypair

See `ssh-hardening.md` — generated with `ssh-keygen`.

---

## What to store (password manager entry example)

```
Server: <server-ip> (<hostname if any>)
SSH:
  Port: <port>
  User: <username>
  Key: ~/.ssh/vps_ed25519 (passphrase: stored separately)
Xray REALITY:
  Private key: <value> (stays on server)
  Public key: <value> (in client configs)
  shortId: <value>
  User UUID: <value>
Marzban:
  Admin user: <username>
  Admin password: <value>
  Dashboard URL/path: <value>
```

---

## See also

- `ssh-hardening.md` — SSH keypair
- `xray-vless-reality.md` — where x25519 keys go in the Xray config
- `xray-vless-tls.md` — where UUID goes in the Xray config
- `marzban.md` — where Marzban secrets go in `.env`
