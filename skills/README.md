# Skills
This directory vendors the “skills” used by the workflow.

The Zsh commands expect these skills to exist under `~/.codex/skills/<skill-name>/...`.

## Install into `~/.codex/skills`
```bash
./scripts/install-skills.sh
```

This uses symlinks (so edits here are reflected immediately).

## Included skills (initial)
- `gh-issue-orchestrator`
- `gh-issue-dev`
- `gh-issue-qa`
- `gh-issue-merge`
- `prd-epic-workflow`
- `epic-decompose`
- `requirements-clarity`
- `agent-learnings`

## Notes
Some skills were originally written for a specific repo.
If you adapt them, keep the *structure* (roles, gates, evidence) but update:
- repo doc entrypoints (e.g. `README.md`, `CONTRIBUTING.md`, `docs/`)
- safety rules for your domain
- test commands / E2E flows
