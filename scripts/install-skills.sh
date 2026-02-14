#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${CODEX_SKILLS_DIR:-$HOME/.codex/skills}"

mkdir -p "$TARGET"

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
  if [[ ! -d "$ROOT/skills/$s" ]]; then
    echo "Missing skill directory: $ROOT/skills/$s" >&2
    exit 1
  fi
  ln -sfn "$ROOT/skills/$s" "$TARGET/$s"
done

echo "Linked ${#skills[@]} skills into: $TARGET"
