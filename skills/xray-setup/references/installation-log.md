# Installation Log Specification

The log file `xray-setup-installation-log.md` must be maintained locally
throughout the session. Use the Write tool to create it after Phase 3
and the Edit tool to append sections after each phase.

## Required fields

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
- Installed components (Xray version, Marzban yes/no, nginx yes/no)
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

## Must NOT include

- SSH private keys
- Passwords of any kind
- Marzban admin password
- UUID used as a VLESS auth credential
- x25519 private key
- Full `.env` contents
- Full VLESS client URI (which contains the UUID)
