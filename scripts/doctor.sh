#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${CODEX_SKILLS_DIR:-$HOME/.codex/skills}"

fail=0

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing command: $1" >&2
    fail=1
  fi
}

need_file() {
  if [[ ! -f "$1" ]]; then
    echo "Missing file: $1" >&2
    fail=1
  fi
}

need_cmd git
need_cmd gh
need_cmd codex

need_file "$ROOT/prompts/impl-orchestrator.md"
need_file "$ROOT/prompts/prd-agent.md"
need_file "$ROOT/zsh/ai-coding-workflow.zsh"

skills=(
  gh-issue-orchestrator
  gh-issue-dev
  gh-issue-qa
  gh-issue-merge
  prd-epic-workflow
  epic-decompose
  requirements-clarity
  agent-learnings
)

for s in "${skills[@]}"; do
  need_file "$TARGET/$s/SKILL.md"
done

if [[ "$fail" -eq 0 ]]; then
  echo "OK: prerequisites + skills look installed"
  exit 0
fi

echo "FAIL: fix the issues above (try: ./scripts/install-skills.sh)" >&2
exit 1
