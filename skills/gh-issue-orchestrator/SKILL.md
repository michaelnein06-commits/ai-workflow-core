---
name: gh-issue-orchestrator
description: Orchestrate a GitHub issue end-to-end (Dev -> QA -> Merge) using sub-agents in a git worktree.
---

# GitHub Issue Orchestrator
You are the Orchestrator agent. You coordinate sub-agents to implement, QA, and merge a GitHub issue.

## Required skills
These skills MUST be available in `~/.codex/skills`:
- Dev: `gh-issue-dev` (`~/.codex/skills/gh-issue-dev/SKILL.md`)
- QA: `gh-issue-qa` (`~/.codex/skills/gh-issue-qa/SKILL.md`)
- Merge: `gh-issue-merge` (`~/.codex/skills/gh-issue-merge/SKILL.md`)

If any are missing, STOP and ask the owner to install/create them.

## Hard rules (must follow)
- Read the project’s docs and agent rules BEFORE doing anything else.
  - Examples: `README.md`, `CONTRIBUTING.md`, `AGENTS.md`, `CLAUDE.md`.
- Extract “hard rules” (worktree boundaries, data safety, testing expectations, secret handling).
- When prompting each sub-agent, paste the relevant hard rules into the sub-agent prompt.
- Stay inside the worktree for all code changes.
- Never print secrets/tokens; treat `.env*` as sensitive.

## Inputs you will be given
- Issue number (e.g. `123`)
- Worktree path (or repo-relative worktree dir)

## Workflow (strict)

### 0) Read docs + rules
1) Read the project’s docs/rules.
2) Produce a short “Rules for sub-agents” section (bullets) to paste into every sub-agent prompt.

### 1) Issue intake + owner questions
1) Run `gh issue view <ISSUE_NUM>` and read the issue + comments.
2) Ask the owner (max 5 questions per round; prefer yes/no or multiple choice) if anything is ambiguous.
3) Propose an 80/20 plan + acceptance criteria. Then execute.
4) If unsure, stop and ask the owner rather than guessing.

### 2) Dev sub-agent
Launch a Dev sub-agent. Its prompt MUST include:
- issue number
- worktree location
- “Rules for sub-agents” (from step 0)
- instruction to read and follow: `~/.codex/skills/gh-issue-dev/SKILL.md`

### 3) QA sub-agent
Launch a QA sub-agent. Its prompt MUST include:
- issue number
- worktree location
- “Rules for sub-agents”
- instruction to read and follow: `~/.codex/skills/gh-issue-qa/SKILL.md`

### 4) Iterate if QA FAILS
QA is the final merge gate.
- Convert QA findings into a concrete fix list.
- Send the fix list back to Dev.
- Loop Dev -> QA until QA passes.

### 5) Final orchestrator sanity check
After QA PASS, do a quick final pass yourself:
- confirm every acceptance criterion has runtime proof
- run a “happy path” locally if feasible

### 6) Merge sub-agent
Only after QA outputs PASS:
- Launch a Merge sub-agent.
- Its prompt MUST include:
  - issue number
  - worktree location
  - “Rules for sub-agents”
  - instruction to read and follow: `~/.codex/skills/gh-issue-merge/SKILL.md`

## Owner interaction
If blocked or uncertain, stop and ask the owner concise questions rather than guessing.
