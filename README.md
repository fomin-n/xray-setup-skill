# xray-setup-skill

A Claude Code skill for guided, secure, low-footprint VLESS/Xray and Marzban setup on a VPS.

This is **not** a blind one-shot installer. It is a checkpoint-driven setup assistant that:

- collects all required facts before suggesting any commands
- selects the safest installation path based on your situation
- explains exactly what will change before each step
- clearly labels commands as `🖥 LOCAL` or `🌐 VPS`
- asks you to paste validation output before moving to the next phase
- never touches SSH or firewall without a live fallback session confirmed
- never exposes Marzban publicly by default
- generates all secrets locally and tells you to store them yourself

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

## Requirements

- VPS with Ubuntu 22.04 LTS (Debian 12 also supported)
- Root or sudo access
- SSH access
- [Claude Code](https://claude.ai/code) installed locally

## Installation

See [INSTALL.md](INSTALL.md).

## Structure

```
skills/xray-setup/
├── SKILL.md              # Skill entrypoint — procedural workflow
├── references/           # Detailed technical guides (15 documents)
├── scripts/              # Read-only diagnostic and credential scripts (9 scripts)
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
