---
name: xray-setup
description: >
  Checkpoint-driven setup assistant for Xray-core VLESS + optional Marzban on a
  remote VPS. Runs locally on the user's machine; orchestrates the VPS entirely
  over SSH — no agent or tool installation on the server required. Asks only the
  minimum SSH connection facts, auto-detects the server state, proposes a
  predicted setup profile for confirmation, then stages the setup with validation
  gates at every phase. Creates a local installation log. Use for: fresh VPS
  setup, adding VLESS to an existing server, Marzban panel install, SSH
  hardening, firewall config, DNS/Cloudflare validation, client import, or
  diagnosing Xray/Marzban/TLS/port/DNS problems.
when_to_use: >
  Trigger when the user mentions: VLESS, Xray, xray-core, Marzban, VPN server,
  proxy server, VPS setup, REALITY protocol, xtls-rprx-vision, SSH VPS
  orchestration, Marzban dashboard, v2ray client, NekoBox, NekoRay, v2rayN,
  FoXray, Streisand, sing-box, or asks how to configure a private proxy or
  secure tunnel on a Linux server they own.
argument-hint: "[scenario: fresh|existing|marzban|troubleshoot]"
allowed-tools:
  - Bash(ssh-keygen*)
  - Bash(ssh-copy-id*)
  - Bash(ssh *)
  - Bash(scp*)
  - Bash(curl*)
  - Bash(dig*)
  - Bash(nslookup*)
  - Bash(ping*)
  - Write
  - Edit
  - Read
model: claude-opus-4-7
effort: high
---

## Execution model

Claude Code runs **locally** on the user's machine.
The VPS is managed **entirely over SSH** — no tools, agents, or scripts are
installed permanently on the server beyond what the setup itself deploys.

**Remote command patterns used throughout this skill:**
```
ssh [-p PORT] USER@HOST 'command'                             # single remote command
ssh [-p PORT] USER@HOST 'bash -s' < scripts/check_ports.sh   # pipe a local script to remote bash
scp [-P PORT] scripts/collect_server_info.sh USER@HOST:/tmp/ # copy script, then run it
```

Define `SSH_TARGET` once at the start of the session and reuse it:
```
SSH_TARGET="USER@HOST"   # add -p PORT to all ssh/scp calls if port ≠ 22
```

All commands in this skill are run **locally**. Commands that execute on the
VPS are wrapped in `ssh $SSH_TARGET '...'`. Never ask the user to manually
SSH in and run commands unless absolutely necessary and explicitly labeled.

---

## Safety invariants (never violate)

- **SSH gate**: Never modify SSH config or firewall until the user confirms a
  second active SSH session is open in a separate terminal.
- **No public dashboard**: Marzban binds to `127.0.0.1:8000` only. Default
  access is SSH tunnel. Never open port 8000 in the firewall.
- **DNS first**: Run `check_dns.sh` before any TLS/certbot step.
- **Port check first**: Run `check_ports.sh` (via SSH) before writing Xray config.
- **No secrets in chat**: Never ask for private keys, x25519 private keys,
  UUIDs used as auth credentials, Marzban admin password, or full `.env`.
  Show generation commands; tell the user to save output locally.
- **Explain before acting**: State exactly what will change before any
  destructive action and get explicit confirmation.
- **Installation log**: Maintain a local file `xray-setup-installation-log.md`
  throughout the session. Never write secrets into it.

---

## Phase 0 — Triage

Detect or ask for the scenario (from `$ARGUMENTS` or context):

- **fresh** — new VPS, no existing services
- **existing** — server has running services
- **marzban** — add Marzban to an existing Xray setup
- **troubleshoot** — something is broken

For **troubleshoot**: ask for symptoms and logs. Consult
`references/troubleshooting.md`. Do not proceed to Phase 1.

---

## Phase 1 — SSH Connection Info

Ask **only** these minimal questions — infer the rest:

1. SSH host or IP (required)
2. SSH user — default: **root**
3. SSH port — default: **22**
4. SSH key or `~/.ssh/config` alias — default: try existing default key or `~/.ssh/config`
5. Do you want Marzban? — default: **yes**
6. Client platforms — show quick choices: iOS / Android / Windows / macOS / Linux
7. Domain name? — default: **no domain**

Present as a short form with defaults pre-filled. Wait for user to confirm
or correct. Then immediately test connectivity.

**Test SSH:**
```
ssh -p PORT -o ConnectTimeout=10 -o BatchMode=yes USER@HOST 'echo "SSH OK"'
```

If connection fails: diagnose (wrong key, wrong port, firewall, wrong IP) before continuing.

If connection succeeds: proceed to Phase 2.

---

## Phase 2 — Server Detection

Run server preflight over SSH. Execute the local script remotely:

```
ssh -p PORT USER@HOST 'bash -s' < skills/xray-setup/scripts/collect_server_info.sh
```

Parse the output silently. Do not ask the user to paste it unless it fails.
Extract:
- OS and kernel version
- Current user and privilege level
- Listening ports (22, 80, 443, 8000, others)
- Docker installed and running containers
- Existing Xray config at `/etc/xray/` or `/opt/xray/`
- Existing Marzban at `/opt/marzban/`
- Running web servers (nginx, angie, caddy)
- Disk and memory

If SSH `bash -s` fails (some hardened servers block it): fall back to
`scp -P PORT skills/xray-setup/scripts/collect_server_info.sh USER@HOST:/tmp/xray-preflight.sh`
then `ssh -p PORT USER@HOST 'bash /tmp/xray-preflight.sh && rm /tmp/xray-preflight.sh'`.

---

## Phase 3 — Predicted Setup Profile

Using Phase 1 answers and Phase 2 server data, construct and display a
**predicted setup profile**. Keep it compact — one screen.

```
╔══ Predicted Setup Profile ══════════════════════════════════╗
║ Execution:     local Claude Code → SSH → VPS               ║
║ SSH target:    root@<IP> -p 22                              ║
║ OS:            Ubuntu 22.04 LTS (detected)                  ║
║ Scenario:      fresh VPS (no conflicting services detected)  ║
║ Transport:     VLESS + REALITY (no domain)                  ║
║   or           VLESS + TLS (domain: <domain>, CF: DNS-only) ║
║ Marzban:       enabled                                       ║
║ Dashboard:     SSH tunnel only (127.0.0.1:8000)             ║
║ Public ports:  SSH(:22) + VLESS(:443)                       ║
║ Port 8000:     loopback only — never public                  ║
║ Clients:       Android, macOS                                ║
╚═════════════════════════════════════════════════════════════╝
```

Ask: **"Does this look right? Reply yes to proceed, or tell me what to change."**

Do not continue until the user confirms.

---

## Phase 4 — Installation Log

Create the local installation log immediately after profile confirmation.
Use the Write tool to create `xray-setup-installation-log.md` in the current
working directory.

The log must include the fields listed at the end of this file under
**Installation Log Specification**. Write only the header and Phase 1–3 data
now. Append more sections as each phase completes.

Tell the user:
> Installation log started at `xray-setup-installation-log.md` in your
> current directory. It will be updated after each phase.

---

## Phase 5 — Safety Pre-flight

Tell the user:

> Before we change anything on the server, open a **second SSH session**
> in a separate terminal and keep it open for the entire setup:
>
> ```
> ssh -p PORT USER@HOST
> ```
>
> If a config change accidentally locks you out, the second session is your
> recovery path. Reply "second session open" when ready.

Wait for confirmation before proceeding.

Back up existing SSH config and any found Xray/Marzban configs:

```
ssh -p PORT USER@HOST 'cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%Y%m%d) 2>/dev/null; echo "backed up"'
```

---

## Phase 6 — SSH Hardening

Skip only if Phase 2 confirmed: PubkeyAuthentication yes AND PasswordAuthentication no.

Follow `references/ssh-hardening.md`. Adapt all commands to run locally via SSH:

**Generate ED25519 keypair (LOCAL — never on the server):**
```
ssh-keygen -t ed25519 -C "vps-$(date +%Y%m)" -f ~/.ssh/vps_ed25519
```

**Copy public key:**
```
ssh-copy-id -i ~/.ssh/vps_ed25519.pub -p PORT USER@HOST
```

**Test key login in the second terminal before proceeding.**

**Disable password auth (only after key login confirmed):**
```
ssh -p PORT USER@HOST "sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config && systemctl reload sshd"
```

**Validate via SSH:**
```
ssh -p PORT USER@HOST 'bash -s' < skills/xray-setup/scripts/check_ssh.sh
```

**Gate:** Output must show `PasswordAuthentication no` and `PubkeyAuthentication yes`.

Update log: SSH hardening status.

---

## Phase 7 — Firewall

Consult `references/firewall.md`.

Before showing any rules, run the port check:
```
ssh -p PORT USER@HOST 'bash -s' < skills/xray-setup/scripts/check_ports.sh
```

Show the port plan as a table, then ask for confirmation before applying:

| Port | Direction | Reason |
|------|-----------|--------|
| PORT (SSH) | IN TCP | SSH access |
| 80 | IN TCP | TLS cert renewal (TLS path only) |
| 443 | IN TCP | VLESS (REALITY or TLS) |

Apply rules via SSH:
```
ssh -p PORT USER@HOST 'bash -s' << 'RULES'
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -p tcp --dport SSH_PORT -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
apt-get install -y iptables-persistent -q && netfilter-persistent save
RULES
```

Verify SSH still works after applying rules. If not, roll back immediately:
```
ssh -p PORT USER@HOST 'iptables -P INPUT ACCEPT; iptables -F'
```

**Gate:** User confirms SSH still accessible after rules applied.

Update log: firewall rules applied, ports.

---

## Phase 8 — Docker

Check via SSH:
```
ssh -p PORT USER@HOST 'bash -s' < skills/xray-setup/scripts/check_docker.sh
```

If Docker not installed, install via apt repository method (not curl|bash):
```
ssh -p PORT USER@HOST 'bash -s' << 'DOCKER'
apt-get update -q
apt-get install -y ca-certificates curl gnupg lsb-release
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list
apt-get update -q
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
systemctl enable docker
echo "DOCKER_OK"
DOCKER
```

Verify:
```
ssh -p PORT USER@HOST 'docker ps && docker compose version && echo "COMPOSE_OK"'
```

**Gate:** Both `docker ps` and `docker compose version` succeed.

Update log: Docker version.

---

## Phase 9 — Credentials

Generate credentials **locally**. Never on the server unless Docker is not
available locally.

Run:
```
bash skills/xray-setup/scripts/gen_credentials.sh
```

Tell the user:
> Save the output to a password manager entry now. Do NOT paste the private
> key, UUID, or shortId back into this chat. When ready to deploy, you will
> paste only the placeholder values into the config templates below.

For REALITY path: x25519 keypair (private key server-side, public key in client URI).
For TLS path: UUID only.

After user confirms credentials are saved, proceed.

---

## Phase 10 — Xray / VLESS Deploy

Route to `references/xray-vless-reality.md` (Path A) or
`references/xray-vless-tls.md` (Path B/C).

Create the directory and config on the server via SSH:

```
ssh -p PORT USER@HOST 'mkdir -p /opt/xray/config /opt/xray/logs'
```

Copy the Docker Compose file and config template to the server:

```
scp -P PORT /tmp/xray-docker-compose.yml USER@HOST:/opt/xray/docker-compose.yml
scp -P PORT /tmp/xray-config.json USER@HOST:/opt/xray/config/config.json
```

Or write directly via SSH heredoc for short files.

Tell the user to fill in the credential placeholders in the config before
copying. Provide the full template with clearly marked `<PLACEHOLDER>` values.

Start Xray:
```
ssh -p PORT USER@HOST 'cd /opt/xray && docker compose up -d && docker compose logs --tail 20'
```

Validate:
```
ssh -p PORT USER@HOST 'bash -s' < skills/xray-setup/scripts/check_xray.sh
```

**Gate:** Container running, config valid, port 443 listening.

Update log: Xray config path, transport, port.

---

## Phase 11 — Angie Proxy (TLS path only)

Skip for REALITY path (Path A).

Consult `references/angie-proxy.md`.

Check DNS first:
```
bash skills/xray-setup/scripts/check_dns.sh DOMAIN SERVER_IP
```

**Gate:** DNS must resolve correctly before certbot runs.

Install Angie and obtain TLS cert via SSH (see `references/angie-proxy.md`
for the full commands). All commands run via `ssh -p PORT USER@HOST '...'`.

Validate TLS locally:
```
bash skills/xray-setup/scripts/check_tls.sh DOMAIN
```

**Gate:** cert valid, CN matches, chain OK.

Update log: TLS cert status, domain, expiry.

---

## Phase 12 — Marzban (if selected in Phase 1)

Consult `references/marzban.md`.

Create Marzban directory and `.env` on server via SSH:
```
ssh -p PORT USER@HOST 'mkdir -p /opt/marzban'

ssh -p PORT USER@HOST 'cat > /opt/marzban/.env' << 'ENV'
UVICORN_HOST = "127.0.0.1"
UVICORN_PORT = 8000
XRAY_JSON = "/var/lib/marzban/xray_config.json"
SQLALCHEMY_DATABASE_URL = "sqlite:////var/lib/marzban/db.sqlite3"
ENV
```

Copy and start Marzban via SSH. See `references/marzban.md` for full
docker-compose.yml and startup commands.

Create admin account (interactive — user must run this themselves):
```
ssh -p PORT -t USER@HOST 'cd /opt/marzban && docker compose exec -it marzban marzban-cli admin create --sudo'
```

The `-t` flag allocates a PTY for the interactive prompt. Admin username
and password are entered interactively — they never appear in this chat.

Configure dashboard access — SSH tunnel by default:
```
ssh -L 8000:127.0.0.1:8000 -p PORT USER@HOST -N
```
Browser: `http://localhost:8000/dashboard/`

Validate:
```
ssh -p PORT USER@HOST 'bash -s' < skills/xray-setup/scripts/check_marzban.sh
```

**Gate:** Container running, port 8000 on `127.0.0.1` only, admin exists.

**External test — must return connection refused or timeout:**
```
curl -m 5 http://SERVER_IP:8000/ 2>&1 | head -3
```

Update log: Marzban status, dashboard access method, admin created (yes/no — no password).

---

## Phase 13 — Validation

Run all checks via SSH. Summarize results in a table:

| Check | Command | Expected result |
|-------|---------|-----------------|
| SSH posture | `ssh ... 'bash -s' < check_ssh.sh` | key-only, no password |
| Ports | `ssh ... 'bash -s' < check_ports.sh` | 443 public, 8000 loopback |
| Docker | `ssh ... 'bash -s' < check_docker.sh` | running |
| Xray | `ssh ... 'bash -s' < check_xray.sh` | container up, config valid |
| TLS (if domain) | `bash check_tls.sh DOMAIN` | valid, non-expired |
| Marzban | `ssh ... 'bash -s' < check_marzban.sh` | 127.0.0.1:8000 only |
| 8000 not public | `curl -m 5 http://IP:8000/` | refused |

If any check fails, pivot to `references/troubleshooting.md`.

Ask user: "Does the client connect? Visit https://ipinfo.io after connecting —
the IP shown should be your VPS IP."

Update log: all validation check results.

---

## Phase 14 — Client Import

Consult `references/client-setup.md`.

Construct the VLESS URI from the confirmed credentials. The URI does not
contain the x25519 private key — only the public key (`pbk=`). It is safe
to display.

Show the URI in a code block. Walk through import for each platform the user
selected in Phase 1.

Update log: client platforms, VLESS URI format used (omit UUID and private key
from log — only note that URI was generated).

---

## Phase 15 — Final Handoff

Write the final summary section to the installation log using the Edit tool.

Tell the user:

> Setup complete. Your installation log is at `xray-setup-installation-log.md`.
>
> Before closing this session:
> 1. Confirm SSH private key is backed up (password manager).
> 2. Confirm credentials (UUID, x25519 keypair, Marzban password) are in
>    your password manager.
> 3. Note SSH port if changed from 22.
> 4. For rollback procedures, see `references/rollback.md`.

Present the final attack surface summary:

| Port | Public? | Service |
|------|---------|---------|
| SSH (22 or custom) | Yes | SSH — key-only auth |
| 80 | Yes (TLS path) | HTTP → HTTPS redirect / certbot |
| 443 | Yes | Xray VLESS (REALITY or TLS) |
| 8000 | No | Marzban dashboard — loopback + SSH tunnel |

---

## Installation Log Specification

The log file `xray-setup-installation-log.md` must be maintained locally
throughout the session. Use the Write tool to create it after Phase 3
and the Edit tool to append sections after each phase.

**Must include:**
- Date/time of setup
- Execution mode (local → SSH → VPS)
- SSH target: USER@HOST:PORT (no private key material)
- Server OS and kernel (from detection)
- Detected existing services and occupied ports
- Selected scenario: fresh / existing / marzban / troubleshoot
- Selected transport: VLESS REALITY or VLESS TLS
- Domain used (yes/no, and domain name if yes)
- DNS status (resolved / not resolved)
- Cloudflare: used or not, DNS-only or proxied if known
- Installed components (Xray version, Marzban yes/no, Angie yes/no)
- Docker Compose project paths
- Important config file paths
- Public ports with services
- Private/loopback-only ports
- Marzban dashboard access method
- Marzban admin created: yes / no (no password in log)
- Validation check results (pass/fail for each phase gate)
- Final attack surface summary
- Backup notes (what was backed up, where)
- Rollback reference
- Next steps for client import (platform list, no URI secrets)

**Must NOT include:**
- SSH private keys
- Passwords of any kind
- Marzban admin password
- UUID used as a VLESS auth credential
- x25519 private key
- Full `.env` contents
- Full VLESS client URI (which contains the UUID)
