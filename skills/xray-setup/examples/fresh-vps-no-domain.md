# Example: Fresh VPS, No Domain — VLESS + REALITY

**Scenario:** Ubuntu 22.04 VPS (Hetzner CX11, 2GB RAM), freshly provisioned.
No domain. User wants to set up VLESS for personal use on Android and macOS.

---

## Phase 0 — Triage

> **User:** I just got a new VPS. I don't have a domain. I want to set up
> Xray VLESS for my own use. I'll use it on my Android phone and Mac.

Skill detects: **fresh** scenario. Proceeds to Phase 1.

---

## Phase 1 — Fact Collection

Skill asks for facts. User provides:

| Fact | Value |
|------|-------|
| VPS provider | Hetzner |
| Server IP | `203.0.113.50` |
| OS | Ubuntu 22.04 LTS |
| Root access | Yes (logged in as root) |
| SSH port | 22 (default) |
| SSH key login | Not set up yet |
| SSH password login | Yes (enabled) |
| Port 80/443/8000 | Nothing running |
| Domain | No |
| Marzban | No for now |
| Client platforms | Android, macOS |

Skill confirms: **Path A — VLESS + REALITY**. No domain, no Angie needed.

---

## Phase 2 — Safety Pre-flight

Skill instructs:

> Please open a second SSH session in a new terminal:
> `ssh root@203.0.113.50`
> Keep it open for the entire setup. Reply "second session open" when ready.

User: "second session open"

Skill proceeds.

---

## Phase 4 — SSH Hardening

**Step 1: Generate keypair (LOCAL)**

```bash
🖥 LOCAL
ssh-keygen -t ed25519 -C "vps-202601" -f ~/.ssh/vps_ed25519
```

Output:
```
Generating public/private ed25519 key pair.
Enter passphrase: ••••••••
Your identification has been saved in /Users/alice/.ssh/vps_ed25519
Your public key has been saved in /Users/alice/.ssh/vps_ed25519.pub
```

**Step 2: Copy to server**

```bash
🖥 LOCAL
ssh-copy-id -i ~/.ssh/vps_ed25519.pub root@203.0.113.50
```

**Step 3: Test in second terminal**

```bash
🖥 LOCAL (second terminal)
ssh -i ~/.ssh/vps_ed25519 root@203.0.113.50
```

User confirms: key login works.

**Step 4: Disable password auth**

```bash
🌐 VPS
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl reload sshd
```

**Step 5: check_ssh.sh output**

```
📋 PASTE OUTPUT
=== SSH Hardening Check ===
  [OK]  PubkeyAuthentication = yes
  [OK]  PasswordAuthentication = no
  [OK]  ChallengeResponseAuthentication = no
  [WARN] PermitRootLogin not explicitly set
  Port: 22 (default)
  [OK]  authorized_keys exists (1 key(s))
    ssh-ed25519
  [OK]  sshd is running
  [WARN] fail2ban is not running (recommended)
```

Skill notes: PermitRootLogin and fail2ban are warnings, not blockers. User
may address them later. SSH gate is confirmed.

---

## Phase 5 — Firewall

Skill shows rules before applying:

| Port | Direction | Purpose |
|------|-----------|---------|
| 22 | IN TCP | SSH |
| 443 | IN TCP | VLESS REALITY |

Port 80 not needed (no certbot for REALITY path).

```bash
🌐 VPS
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
apt-get install -y iptables-persistent && netfilter-persistent save
```

User tests SSH in new terminal: ✓ works.

```
📋 PASTE OUTPUT: check_ports.sh
=== Port Check ===
  [OK]  Port 22: listening on 0.0.0.0
  [WARN] Port 80: not listening — expected public [HTTP / ACME challenge]
  [WARN] Port 443: not listening — expected public [VLESS / HTTPS]
  [OK]  Port 8000: closed / not listening [Marzban dashboard — MUST be loopback]
```

Port 443 not yet listening is expected — Xray not installed yet.

---

## Phase 6 — Docker

```bash
🌐 VPS
apt-get update && apt-get install -y ca-certificates curl gnupg lsb-release
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list
apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
systemctl enable docker
```

```
📋 PASTE OUTPUT: check_docker.sh
  [OK]  Docker binary found: /usr/bin/docker
  [OK]  Docker daemon is running
  [OK]  Docker Compose version v2.23.0
  [OK]  User root can run docker without sudo
```

---

## Phase 7 — Xray REALITY Setup

**Generate credentials (LOCAL):**

```bash
🖥 LOCAL
bash scripts/gen_credentials.sh
```

```
--- x25519 Keypair ---
Private key: 8J3...EXAMPLE_PRIVATE_KEY...abc  (server only — save to password manager)
Public key:  kX9...EXAMPLE_PUBLIC_KEY...xyz

--- VLESS User UUID ---
UUID: a1b2c3d4-e5f6-7890-abcd-ef1234567890

--- REALITY shortId ---
shortId: f4a3b2c1d0e9f8a7
```

User saves all values locally.

**Create Xray config on VPS:**

```bash
🌐 VPS
mkdir -p /opt/xray/config /opt/xray/logs
```

Create `/opt/xray/config/config.json` (fill in credentials — see
`references/xray-vless-reality.md` for the full template):

- `privateKey`: the private key from gen_credentials.sh
- `clients[].id`: the UUID
- `shortIds`: the shortId

**Create `/opt/xray/docker-compose.yml`** (from `references/xray-vless-reality.md`).

```bash
🌐 VPS
cd /opt/xray && docker compose up -d
```

```
📋 PASTE OUTPUT: check_xray.sh
=== Xray Check ===
  [OK]  Directory exists
  [OK]  Container 'xray' is running
  Image: ghcr.io/xtls/xray-core:latest | Status: Up 2 minutes | Ports: 0.0.0.0:443->443/tcp
  Xray version: Xray 24.x.x (XTLS)
  [OK]  config.json is valid JSON
  [OK]  Xray config passes validation
  [OK]  Port 443 is listening
  [OK]  No errors in last 100 log lines
```

---

## Phase 10 — Client Setup

Skill generates VLESS URI:

```
vless://a1b2c3d4-e5f6-7890-abcd-ef1234567890@203.0.113.50:443?security=reality&sni=www.microsoft.com&fp=chrome&pbk=kX9...EXAMPLE_PUBLIC_KEY...xyz&sid=f4a3b2c1d0e9f8a7&flow=xtls-rprx-vision&type=tcp#Hetzner-REALITY
```

(In real use, replace EXAMPLE values with actual generated credentials.)

**Android (NekoBox):** Tap + → Import from clipboard → paste URI → connect.

**macOS (V2Box):** App Store → V2Box → + → Import from clipboard → connect.

---

## Phase 11 — Validation

User visits `https://ipinfo.io` after connecting: shows VPS IP `203.0.113.50`. ✓

Final security summary:

| Port | Public? | Service |
|------|---------|---------|
| 22 | Yes | SSH (key-only) |
| 443 | Yes | Xray VLESS REALITY |
| All others | No | — |
