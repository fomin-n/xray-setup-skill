# Firewall Setup

## Approach

Use iptables with an **allowlist (default DROP)** policy for INPUT.
This means only explicitly allowed ports accept connections; everything
else is silently dropped.

ufw is simpler for beginners but iptables gives finer control and is
what most Xray guides use. Both are covered below.

---

## Port plan by scenario

| Port | Protocol | Needed for |
|------|----------|-----------|
| SSH (22 or custom) | TCP | SSH access — always first |
| 80 | TCP | Let's Encrypt ACME challenge + HTTP→HTTPS redirect (TLS path) |
| 443 | TCP | VLESS (REALITY or TLS) |
| 8000 | — | Marzban — loopback only, no public rule needed |

For REALITY path: port 80 is optional (no certbot needed). You may close it.

---

## iptables method

### Check current rules first

```bash
🌐 VPS
sudo iptables -L INPUT -n --line-numbers
```

### Set default DROP policy (INPUT and FORWARD)

```bash
🌐 VPS — ONLY after SSH rule is confirmed below
sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT ACCEPT
```

### Allow established connections (required)

```bash
🌐 VPS
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A INPUT -i lo -j ACCEPT
```

### Allow SSH (replace 22 with your port if changed)

```bash
🌐 VPS
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
```

### Allow HTTP and HTTPS (TLS path)

```bash
🌐 VPS
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
```

For REALITY path, port 80 is optional:

```bash
🌐 VPS — REALITY path, if you want ICMP (ping) for diagnostics
sudo iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
```

### Persist rules (Ubuntu/Debian)

```bash
🌐 VPS
sudo apt-get install -y iptables-persistent
sudo netfilter-persistent save
```

Or manually:

```bash
🌐 VPS
sudo iptables-save | sudo tee /etc/iptables/rules.v4
```

Add to `/etc/rc.local` or a systemd unit if `iptables-persistent` is not used.

---

## ufw method (simpler alternative)

```bash
🌐 VPS
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow <SSH_PORT>/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

Verify:

```bash
🌐 VPS
sudo ufw status verbose
```

---

## Validation

Run check_ports.sh on the VPS after applying rules:

```bash
🌐 VPS — paste output
bash scripts/check_ports.sh
```

Expected: only SSH, 80, 443 appear in the listening list. Port 8000 must
appear as `127.0.0.1:8000` only (if Marzban installed), never `0.0.0.0:8000`.

From outside the server (local machine):

```bash
🖥 LOCAL
nmap -p 22,80,443,8000 <server-ip>
```

Expected: 22 open, 80 open (TLS path) or closed (REALITY), 443 open,
8000 filtered/closed.

---

## After confirming firewall, test SSH

Open a new terminal and SSH in before closing anything:

```bash
🖥 LOCAL (new terminal)
ssh -i ~/.ssh/vps_ed25519 -p <SSH_PORT> <user>@<server-ip>
```

If this fails, revert the default policy from your existing session:

```bash
🌐 VPS (existing session — emergency rollback)
sudo iptables -P INPUT ACCEPT
```

Then diagnose and re-apply correctly.

---

## See also

- `ssh-hardening.md` — SSH port configuration
- `rollback.md#firewall-rollback` — reset all iptables rules
- `overview.md` — port plan per scenario
