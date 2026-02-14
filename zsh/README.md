# Zsh commands
This repo provides a small set of Zsh functions intended to be sourced from your `~/.zshrc`.

## Install
1) Install/Link the skills:
```bash
./scripts/install-skills.sh
```

2) Source the commands (add to `~/.zshrc`):
```bash
source /absolute/path/to/ai-coding-workflow/zsh/ai-coding-workflow.zsh
```

3) Restart your shell.

## Configuration
You can override defaults via env vars:
- `AIWF_CODEX_MODEL` (default: `gpt-5.2`)
- `AIWF_ENFORCE_CLEAN_ROOT` (default: `1`)
- `AIWF_LINK_ENV_FILES` (default: `1`) — symlink `.env*` from repo root into the issue worktree
- `CODEX_SKILLS_DIR` (default: `~/.codex/skills`)

## Usage
- `prd "draft an epic for …"`
- `impl 123 "extra instructions if needed"`
