# Installation

## Requirements

- [Claude Code](https://claude.ai/code) CLI installed
- Claude Code version that supports skills (`~/.claude/skills/`)

## Install (personal scope)

```bash
cp -r skills/xray-setup ~/.claude/skills/
```

Verify the skill is available:

```bash
claude --list-skills 2>/dev/null | grep xray-setup || echo "Restart Claude Code and type /xray-setup to confirm"
```

## Use as project skill

If you want the skill available only within a specific project directory:

```bash
mkdir -p /path/to/your/project/.claude/skills/
cp -r skills/xray-setup /path/to/your/project/.claude/skills/
```

## Update

Pull the latest version and re-copy:

```bash
git pull
cp -r skills/xray-setup ~/.claude/skills/
```

## Uninstall

```bash
rm -rf ~/.claude/skills/xray-setup
```

## Invoke

In any Claude Code session:

```
/xray-setup
```

Or with a scenario hint:

```
/xray-setup fresh
/xray-setup existing
/xray-setup marzban
/xray-setup troubleshoot
```
