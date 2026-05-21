# SSH Hardening

## Goal

- ED25519 key-based authentication only
- Password authentication disabled
- Fail2ban installed for brute-force protection
- SSH port optionally changed from 22 (document if changed)

## CRITICAL: Second-session gate

Before changing any SSH configuration, the user must open a second SSH
session in a separate terminal and keep it open. If a misconfiguration
locks out the primary session, the second session is the recovery path.

**Confirm before proceeding:** "I have a second SSH session open."

---

## Step 1 — Generate ED25519 keypair

Run on your **local machine** (not the server):

```bash
🖥 LOCAL
ssh-keygen -t ed25519 -C "vps-$(date +%Y%m)" -f ~/.ssh/vps_ed25519
```

This creates:
- `~/.ssh/vps_ed25519` — private key (never share, never paste into chat)
- `~/.ssh/vps_ed25519.pub` — public key (safe to copy to server)

Store the private key passphrase in your password manager.

---

## Step 2 — Copy public key to server

```bash
🖥 LOCAL
ssh-copy-id -i ~/.ssh/vps_ed25519.pub -p <SSH_PORT> <user>@<server-ip>
```

Or manually (if `ssh-copy-id` is not available):

```bash
🖥 LOCAL — get the public key content
cat ~/.ssh/vps_ed25519.pub
```

Then on the server:

```bash
🌐 VPS
mkdir -p ~/.ssh && chmod 700 ~/.ssh
echo "PASTE_PUBLIC_KEY_HERE" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

---

## Step 3 — Test key login (MANDATORY before next step)

**In your second terminal**, test the key:

```bash
🖥 LOCAL (second terminal)
ssh -i ~/.ssh/vps_ed25519 -p <SSH_PORT> <user>@<server-ip>
```

If this succeeds, proceed. If it fails, do NOT disable password auth —
troubleshoot key login first. Common issues:
- Wrong permissions on `~/.ssh/` or `authorized_keys` on server
- `PubkeyAuthentication` disabled in `sshd_config`
- Key not copied correctly (extra newline, truncation)

---

## Step 4 — Disable password authentication

Only after Step 3 succeeds in your second terminal:

```bash
🌐 VPS
sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#*UsePAM.*/UsePAM no/' /etc/ssh/sshd_config
```

Verify the file before reloading:

```bash
🌐 VPS
grep -E '^(PasswordAuthentication|PubkeyAuthentication|ChallengeResponseAuthentication|UsePAM)' /etc/ssh/sshd_config
```

Expected output:

```
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
UsePAM no
```

Reload SSH daemon:

```bash
🌐 VPS
sudo systemctl reload sshd
```

Test again from the second terminal. If locked out, use the still-open
first session or VPS provider emergency console.

---

## Step 5 — Optional: change SSH port

Only do this if you have a specific reason (e.g., reduce noise from port
scanners). Tradeoff: increases operational complexity, easy to forget.

If you change the port, **update your firewall FIRST** to allow the new port:

```bash
🌐 VPS
sudo iptables -I INPUT -p tcp --dport <NEW_PORT> -j ACCEPT
```

Then change in sshd_config:

```bash
🌐 VPS
sudo sed -i 's/^#*Port 22/Port <NEW_PORT>/' /etc/ssh/sshd_config
sudo systemctl reload sshd
```

Test the new port from your second terminal before removing port 22 from
the firewall.

---

## Step 6 — Install fail2ban

```bash
🌐 VPS
sudo apt-get update && sudo apt-get install -y fail2ban
```

Create a local jail config:

```bash
🌐 VPS
sudo tee /etc/fail2ban/jail.local << 'EOF'
[sshd]
enabled = true
port    = ssh
filter  = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime  = 3600
findtime = 600
EOF

sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

Verify:

```bash
🌐 VPS
sudo fail2ban-client status sshd
```

---

## Validation

Run on the VPS:

```bash
🌐 VPS — paste output to confirm
bash scripts/check_ssh.sh
```

Expected clean output:
- PubkeyAuthentication: yes
- PasswordAuthentication: no
- Authorized keys: present
- fail2ban: active (if installed)

---

## Rollback

If you are locked out, use your VPS provider's emergency web console (KVM/VNC)
to log in and revert `sshd_config`. See `rollback.md#ssh-lockout-recovery`.

## See also

- `firewall.md` — add SSH port to allowlist
- `rollback.md` — SSH lockout recovery
