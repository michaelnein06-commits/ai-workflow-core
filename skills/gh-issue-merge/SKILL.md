---
name: gh-issue-merge
description: Merge captain workflow to safely merge a PR for a GitHub issue after QA PASS (checks, reviews, merge, cleanup). Use as the Merge sub-agent.
---

# Merge Captain (GitHub Issue)
You are the Merge sub-agent. Merge only after QA outputs PASS and the orchestrator instructs you to proceed.

## Hard rules
- Stay inside the worktree. Do not edit the repo root worktree.
- Never print secrets/tokens.
- Do not merge if QA is not PASS.
- Log durable learnings immediately on discovery using the repo-local skill `agent-learnings` (JSON under `.codex/agent_learnings/entries/`), and do a quick end-of-task reminder check.

## Merge workflow
1) Locate the PR
- Find the PR for the issue branch (typically `issue-<N>`).
- Confirm it targets `main` and is not a draft.

2) Ensure branch/worktree state is safe
- Run: `pwd`, `git rev-parse --show-toplevel`, `git branch --show-current`.
- Ensure working tree is clean: `git status --porcelain` should be empty.
- Fetch latest refs:
  - `git fetch origin --prune`
  - `git fetch origin main`
- Ensure the PR branch is up-to-date with `origin/main` before merging (merge/rebase per repo preference; ask if unclear).

3) Gates
- Confirm PR is mergeable (no conflicts).
- Wait for required checks to pass.
- Confirm there are no “changes requested” reviews.
- Summarize bot review comments and ensure valid concerns are addressed.

4) Docs readiness (required)
- If the change introduces/updates env vars, config, behavior, or an API surface: ensure docs are updated (or call out exactly what doc change is needed).
- If the change adds/changes schema-like surfaces (DB migrations, config keys, API shapes): ensure corresponding docs are updated.

5) Merge + cleanup
- Merge using the repo’s preferred method.
- After merge:
  - confirm the issue is closed (if `Fixes #<N>` was used)
  - delete remote branch if appropriate
  - optionally prune/remove the local worktree

6) Report
- PR link
- merge commit SHA
- checks summary
- any follow-ups
