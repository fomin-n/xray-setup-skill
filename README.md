# xray-setup-skill

A Claude Code skill for guided, secure, low-footprint VLESS/Xray and Marzban setup on a remote VPS.

- runs on your **local machine** — no tools installed on the VPS beyond what the setup deploys
- orchestrates the remote VPS entirely **over SSH** using `ssh user@host '...'` and `bash -s` piping
- asks for minimal SSH connection info, then auto-detects server state
- proposes a compact **predicted setup profile** for you to confirm before changing anything
- explains exactly what will change before each step
- never touches SSH or firewall without a live fallback session confirmed
- never exposes Marzban publicly by default
- generates all secrets locally and tells you to store them yourself
- maintains a local **installation log** (`xray-setup-installation-log.md`) throughout the session

## What you get

- **Xray-core** running in Docker
- **VLESS** with REALITY (no domain needed) or TLS (with domain)
- Optional **Marzban** management panel, accessible via SSH tunnel only by default
- **Angie** as TLS terminator with HTTPS fallback site
- Hardened SSH posture (ED25519 keys, no password auth)
- Strict iptables firewall (allowlist approach)
- Client configuration for iOS, Android, Windows, macOS, Linux

## Supported scenarios

| Scenario | Description |
|----------|-------------|
| `fresh` | New VPS, no existing services. REALITY (no domain) or TLS (with domain). |
| `existing` | Server already has services. Inspect first, migrate conservatively. |
| `marzban` | Add or fix Marzban on an existing Xray setup. |
| `troubleshoot` | Something is broken. Guided diagnosis from symptoms to fix. |

## How it works

```
Your machine                    Remote VPS
──────────────────────          ──────────────────────
Claude Code                     Docker
xray-setup skill         SSH    Xray-core (VLESS)
SSH keys              ───────►  optional Marzban
installation log                firewall rules
```

Claude Code runs locally. Every VPS operation is executed via
`ssh user@host 'command'` or `ssh user@host 'bash -s' < script.sh`.
No agent or extra tooling is installed on the VPS.

## Requirements

- VPS with Ubuntu 22.04 LTS (Debian 12 also supported)
- Root or sudo access via SSH
- SSH key authentication (password login can be set up during the skill run)
- [Claude Code](https://claude.ai/code) installed on your **local** machine

## Installation

See [INSTALL.md](INSTALL.md).

## Structure

```
skills/xray-setup/
├── SKILL.md              # Skill entrypoint — 15-phase SSH-orchestrated workflow
├── references/           # Detailed technical guides (15 documents)
├── scripts/              # Diagnostic and credential scripts (10 scripts)
│   ├── ssh_preflight.sh  # Test SSH connectivity and detect server state (LOCAL)
│   ├── collect_server_info.sh  # Full server snapshot via SSH pipe
│   ├── check_ssh.sh / check_ports.sh / check_docker.sh
│   ├── check_xray.sh / check_marzban.sh / check_tls.sh / check_dns.sh
│   └── gen_credentials.sh      # Generate x25519 keypair, UUID, shortId (LOCAL)
└── examples/             # Annotated walkthrough scenarios (5 examples)
```

## Security posture

- No default credentials anywhere
- All secrets generated with `openssl rand` or Docker x25519 — never hardcoded
- Marzban dashboard never exposed on a public port by default
- Firewall uses INPUT DROP default with explicit ACCEPT rules
- SSH hardening includes mandatory second-session gate before any config change
- Rollback procedures documented for every phase including emergency console recovery

## References

- [Akiyamov xray-vps-setup](https://github.com/Akiyamov/xray-vps-setup)
- [Marzban official docs](https://gozargah.github.io/marzban/en/docs/installation)
- [Xray / Project X docs](https://xtls.github.io/en/)
- [VLESS inbound configuration](https://xtls.github.io/en/config/inbounds/vless.html)
- [Claude Code skills documentation](https://code.claude.com/docs/en/skills)

## License

MIT
