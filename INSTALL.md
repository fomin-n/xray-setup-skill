# Installation

## Requirements

- [Claude Code](https://claude.ai/code) CLI installed

## Install (personal scope)

```bash
mkdir -p ~/.claude/skills
cp -r skills/xray-setup ~/.claude/skills/
```

> If `~/.claude/skills/` did not exist before this command, restart Claude Code
> so it picks up the new skills directory.

Verify the skill is available by typing `/xray-setup` in any Claude Code session.

## Use as project skill

To make the skill available only within a specific project:

```bash
mkdir -p /path/to/your/project/.claude/skills/
cp -r skills/xray-setup /path/to/your/project/.claude/skills/
```

The skill is active when Claude Code is opened inside that project directory.

## Update

```bash
git pull
rm -rf ~/.claude/skills/xray-setup
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
