# AI coding workflow (open-source, sanitized)
# Source this file from ~/.zshrc

# Resolve repo root of this workflow (works even when sourced)
AIWF_DIR=${AIWF_DIR:-${${(%):-%N}:A:h}}
AIWF_ROOT=${AIWF_ROOT:-${AIWF_DIR:h}}

# Defaults
: ${AIWF_CODEX_MODEL:=gpt-5.2}
: ${AIWF_ENFORCE_CLEAN_ROOT:=1}
: ${AIWF_LINK_ENV_FILES:=1}
: ${CODEX_SKILLS_DIR:=$HOME/.codex/skills}

_aiwf_err() { print -u2 -- "$*" }

_aiwf_require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { _aiwf_err "Missing command: $1"; return 1; }
}

_aiwf_repo_root() {
  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || return 1
  if [[ "$repo_root" == *".worktrees"* ]]; then
    repo_root="${repo_root%%/.worktrees*}"
  fi
  print -r -- "$repo_root"
}

_aiwf_require_clean_root() {
  local repo_root="$1"

  [[ "$AIWF_ENFORCE_CLEAN_ROOT" == "1" ]] || return 0

  local root_branch
  root_branch=$(git -C "$repo_root" branch --show-current 2>/dev/null) || return 1
  if [[ "$root_branch" != "main" ]]; then
    _aiwf_err "Error: repo root must be on main (currently: $root_branch)."
    return 1
  fi

  if [[ -n "$(git -C "$repo_root" status --porcelain)" ]]; then
    _aiwf_err "Error: repo root working tree is not clean."
    return 1
  fi
}

_aiwf_require_skill_file() {
  local skill_dir="$1"
  local skill_file="$CODEX_SKILLS_DIR/$skill_dir/SKILL.md"
  [[ -f "$skill_file" ]] || {
    _aiwf_err "Missing required skill: $skill_file"
    _aiwf_err "Fix: (cd $AIWF_ROOT && ./scripts/install-skills.sh)"
    return 1
  }
}

_aiwf_worktree_for_issue() {
  local repo_root="$1"
  local issue_num="$2"
  local branch_name="issue-$issue_num"
  local worktree_rel=".worktrees/$branch_name"
  local worktree_dir="$repo_root/$worktree_rel"

  # If already checked out elsewhere, reuse it.
  local existing_worktree
  existing_worktree=$(git -C "$repo_root" worktree list --porcelain | grep -B 2 "refs/heads/$branch_name" | grep "^worktree " | cut -d ' ' -f 2-)
  if [[ -n "$existing_worktree" ]]; then
    worktree_dir="$existing_worktree"
    if [[ "$worktree_dir" == "$repo_root/"* ]]; then
      worktree_rel="${worktree_dir#$repo_root/}"
    else
      worktree_rel="$worktree_dir"
    fi
  else
    git -C "$repo_root" worktree prune >/dev/null 2>&1 || true
    mkdir -p "$repo_root/.worktrees"

    # Best-effort: update origin refs
    git -C "$repo_root" fetch origin main >/dev/null 2>&1 || git -C "$repo_root" fetch origin >/dev/null 2>&1 || true

    if git -C "$repo_root" show-ref --verify --quiet "refs/heads/$branch_name"; then
      git -C "$repo_root" worktree add "$worktree_dir" "$branch_name"
    else
      local base_ref="origin/main"
      if ! git -C "$repo_root" show-ref --verify --quiet "refs/remotes/origin/main"; then
        base_ref="main"
      fi
      git -C "$repo_root" worktree add -b "$branch_name" "$worktree_dir" "$base_ref"
    fi
  fi

  print -r -- "$worktree_rel|$worktree_dir"
}

_aiwf_set_title() {
  local title="$1"
  printf "\e]1;%s\a" "$title"
  printf "\e]2;%s\a" "$title"
}

_aiwf_fill_template() {
  local template_file="$1"
  local issue_num="$2"
  local worktree_rel="$3"

  local body
  body=$(cat "$template_file") || return 1
  body="${body//__ISSUE_NUM__/$issue_num}"
  body="${body//__WORKTREE_REL__/$worktree_rel}"
  print -r -- "$body"
}

# --- Public commands ---

prd() {
  _aiwf_require_cmd git || return 1
  _aiwf_require_cmd codex || return 1

  _aiwf_require_skill_file prd-epic-workflow || return 1
  _aiwf_require_skill_file requirements-clarity || return 1

  local repo_root
  repo_root=$(_aiwf_repo_root) || { _aiwf_err "Error: run prd from inside the target git repo."; return 1; }

  cd "$repo_root" || return 1
  _aiwf_set_title "PRD"

  local user_prompt="$*"
  local prompt_file="$AIWF_ROOT/prompts/prd-agent.md"
  [[ -f "$prompt_file" ]] || { _aiwf_err "Missing prompt template: $prompt_file"; return 1; }

  local final_prompt
  final_prompt=$(cat "$prompt_file")
  if [[ -n "$user_prompt" ]]; then
    final_prompt="$user_prompt

$final_prompt"
  fi

  codex --search --enable collab --enable collaboration_modes \
    --sandbox workspace-write --ask-for-approval on-request \
    -m "$AIWF_CODEX_MODEL" -c 'model_reasoning_effort="high"' \
    "$final_prompt"
}

impl() {
  local issue_num="$1"
  shift || true
  local user_prompt="$*"

  if [[ -z "$issue_num" ]]; then
    _aiwf_err "Usage: impl <issue-number> [optional prompt]"
    return 1
  fi

  _aiwf_require_cmd git || return 1
  _aiwf_require_cmd gh || return 1
  _aiwf_require_cmd codex || return 1

  _aiwf_require_skill_file gh-issue-orchestrator || return 1
  _aiwf_require_skill_file gh-issue-dev || return 1
  _aiwf_require_skill_file gh-issue-qa || return 1
  _aiwf_require_skill_file gh-issue-merge || return 1

  local repo_root
  repo_root=$(_aiwf_repo_root) || { _aiwf_err "Error: not in a git repo."; return 1; }
  _aiwf_require_clean_root "$repo_root" || return 1

  local wt
  wt=$(_aiwf_worktree_for_issue "$repo_root" "$issue_num") || return 1
  local worktree_rel="${wt%%|*}"
  local worktree_dir="${wt#*|}"

  # Optional: link .env files from repo root into the worktree (single source of truth)
  if [[ "$AIWF_LINK_ENV_FILES" == "1" ]]; then
    local env_ts
    env_ts=$(date +%Y%m%d-%H%M%S)

    local src base dest linked_any
    linked_any=0
    for src in "$repo_root"/.env*(.N); do
      if [[ $linked_any -eq 0 ]]; then
        linked_any=1
      fi

      base="${src##*/}"
      dest="$worktree_dir/$base"

      if [[ -e "$dest" && ! -L "$dest" ]]; then
        mv "$dest" "$dest.bak.$env_ts"
      fi

      ln -sfn "$src" "$dest"
    done
  fi

  cd "$worktree_dir" || return 1
  _aiwf_set_title "Impl #$issue_num"

  local prompt_file="$AIWF_ROOT/prompts/impl-orchestrator.md"
  [[ -f "$prompt_file" ]] || { _aiwf_err "Missing prompt template: $prompt_file"; return 1; }

  local orchestrator_prompt
  orchestrator_prompt=$(_aiwf_fill_template "$prompt_file" "$issue_num" "$worktree_rel") || return 1

  local final_prompt="$orchestrator_prompt"
  if [[ -n "$user_prompt" ]]; then
    final_prompt="$user_prompt

$orchestrator_prompt"
  fi

  # NOTE: flags are intentionally explicit; adjust to your Codex CLI version.
  ( cd "$repo_root" && codex --search \
      --enable collab --enable collaboration_modes \
      --dangerously-bypass-approvals-and-sandbox \
      -m "$AIWF_CODEX_MODEL" -c 'reasoning.effort="high"' \
      -C "$worktree_rel" "$final_prompt" )
}
