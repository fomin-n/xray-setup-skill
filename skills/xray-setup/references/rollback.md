# Rollback Procedures

## Guiding principle

Every destructive action taken during setup should have a documented undo.
Attempt rollback in reverse order of the phase that introduced the change.

---

## SSH lockout recovery {#ssh-lockout-recovery}

**Symptom:** Cannot SSH into the server. All terminals are disconnected.

**Recovery via VPS provider emergency console:**

1. Log in to your VPS provider dashboard (Hetzner, DigitalOcean, Vultr, etc.)
2. Open the server's web console (KVM / VNC / Emergency Console)
3. Log in as root using the root password set during VPS provisioning
4. Revert `sshd_config`:

```bash
sudo nano /etc/ssh/sshd_config
# Change: PasswordAuthentication no → PasswordAuthentication yes
# Or restore from backup (see below)
sudo systemctl restart sshd
```

5. SSH in normally, diagnose the issue, then re-apply hardening correctly.

**Backup before changing sshd_config (do this before Phase 4):**

```bash
🌐 VPS
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%Y%m%d)
```

To restore:

```bash
🌐 VPS
sudo cp /etc/ssh/sshd_config.bak.<DATE> /etc/ssh/sshd_config
sudo systemctl reload sshd
```

---

## Firewall rollback {#firewall-rollback}

**Symptom:** Firewall rules applied but something is now unreachable.

**Full reset (open everything temporarily):**

```bash
🌐 VPS
sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -P OUTPUT ACCEPT
sudo iptables -F
sudo iptables -X
```

Then reapply rules correctly using the procedure in `firewall.md`.

**ufw:**

```bash
🌐 VPS
sudo ufw disable
```

---

## Docker Xray rollback {#xray-rollback}

**Stop and remove Xray container:**

```bash
🌐 VPS
cd /opt/xray
docker compose down
```

**Remove Xray data (destructive):**

```bash
🌐 VPS — confirm before running
sudo rm -rf /opt/xray
```

**Revert port 443 (if Xray was occupying it):**

After stopping Xray, port 443 is free for any previous service.

**Backup config before changes:**

```bash
🌐 VPS
cp /opt/xray/config/config.json /opt/xray/config/config.json.bak.$(date +%Y%m%d%H%M)
```

---

## Angie rollback {#angie-rollback}

**Revert configuration change:**

```bash
🌐 VPS
sudo cp /etc/angie/http.d/xray.conf.bak /etc/angie/http.d/xray.conf
sudo angie -t && sudo systemctl reload angie
```

**Stop Angie:**

```bash
🌐 VPS
sudo systemctl stop angie
```

**Remove Angie (not usually needed):**

```bash
🌐 VPS
sudo apt-get remove -y angie
```

---

## TLS certificate rollback

Let's Encrypt certificates can be revoked and deleted:

```bash
🌐 VPS
sudo certbot revoke --cert-path /etc/letsencrypt/live/<YOUR_DOMAIN>/fullchain.pem
sudo certbot delete --cert-name <YOUR_DOMAIN>
```

---

## Marzban rollback {#marzban-rollback}

**Stop Marzban:**

```bash
🌐 VPS
cd /opt/marzban
docker compose down
```

**Backup Marzban data before removal:**

```bash
🌐 VPS
sudo cp -r /opt/marzban /opt/marzban.bak.$(date +%Y%m%d)
```

**Remove Marzban data (destructive):**

```bash
🌐 VPS — destructive, confirm first
sudo rm -rf /opt/marzban
```

**Verify port 8000 is free:**

```bash
🌐 VPS
ss -tlnp | grep 8000
```

---

## Full server reset

If nothing can be recovered: **rebuild the VPS** using your provider's
snapshot/restore feature, or provision a fresh instance.

Before doing this, collect any logs you need for diagnosis:

```bash
🌐 VPS
docker logs xray > /tmp/xray-final.log 2>&1
docker logs marzban >> /tmp/xray-final.log 2>&1
sudo journalctl -u sshd --since "1 hour ago" >> /tmp/xray-final.log 2>&1
```

Download the log file before destroying:

```bash
🖥 LOCAL
scp -P <SSH_PORT> <user>@<server-ip>:/tmp/xray-final.log ./
```

---

## Backup checklist (save these before starting setup)

- [ ] `/etc/ssh/sshd_config` backed up with date suffix
- [ ] Any existing nginx/angie config backed up
- [ ] Any existing Xray config backed up
- [ ] VPS root password stored in password manager
- [ ] VPS provider web console access confirmed working

## See also

- `ssh-hardening.md` — second-session gate
- `firewall.md` — iptables rules
- `troubleshooting.md` — diagnosis before rollback
