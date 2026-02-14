---
name: prd-epic-workflow
description: Run the PRD/EPIC workflow (requirements → simplification → decision-complete EPIC + child TASK breakdown with Execution/Proof).
---

# PRD / EPIC Workflow (AI-only pipeline)

Use this skill whenever starting meaningful work, rewriting an EPIC, or splitting an EPIC into child TASKs.

## Hard rules

- EPICs are never closed by PRs. PRs close TASKs only.
- Every TASK must include a literal line near the top: `Epic: #<N>` (where `#<N>` is an EPIC issue).
- Every EPIC must include a final TASK titled: `Execution: run end-to-end + post evidence`.
- “Solved” means executed end-to-end with concrete evidence, not “code written”.
- Do NOT limit questions. Ask as many rounds as needed to be decision-complete.
- Be specific and verifiable.
- Log durable learnings immediately on discovery using the repo-local skill `agent-learnings`, and do a quick end-of-task reminder check.

## Base rubric (required)

Use `$requirements-clarity` as the scoring rubric and structure:
- Maintain a clarity score (0–100) and iterate until ≥ 90/100 before finalizing the EPIC.
- Track clarification rounds.

Adaptations (project-specific):
- Output is GitHub issue markdown only (no docs/prds files).
- Question format must be multiple-choice so the owner can answer quickly like: `1a, 2c, 3a (+ note...)`.

## What “incredibly thorough” means here

An EPIC/PRD passes only if it is **decision-complete**:
- A dev agent can implement without asking clarifying questions.
- QA can prove pass/fail with commands + expected outputs.
- If a script/backfill is involved, the plan includes a safe dry-run, a full run across the defined “ALL records” cohort, and a required evidence comment format.

## Workflow

### 0) Preflight (always do this first)

1. Load the issue fresh (do not trust memory):
   - `gh issue view <N> --json title,body,labels,comments,updatedAt`
2. Confirm the hierarchy:
   - This PRD/EPIC issue: labels must include `type:epic`.
3. Route required reading (based on the “primary area”):
   - Always read your project’s docs/rules first.
     - Examples: `README.md`, `CONTRIBUTING.md`, `AGENTS.md`, `docs/`.
   - Then read the area-specific docs for the thing you’re changing (API, workers, data model, UI, etc.).
4. Check for “do-not-change” constraints that must be repeated in every TASK.

### Question style (required)

Ask one decision at a time using this structure:

1. The question (what decision we are making)
   a) Option A (Recommended) — why recommended
   b) Option B — tradeoff
   c) Option C — tradeoff
   d) Other — owner free-form

(Optional) What changes in the plan based on the answer.

If you cannot offer meaningful alternatives, stop and do more discovery first.

### 1) PRD interrogation (requirements gathering — ask until locked)

Use `QUESTION_BANK.md` and do not proceed until every applicable section has explicit answers.
If something is unknown, it must be labeled as an **assumption** with an explicit default.

Read: `QUESTION_BANK.md` (required).

Minimum required outputs from this phase:
- **Problem statement** (2 sentences):
  - What the user/system observes
  - Why it matters (risk/impact)
- **Goal** (WHY + expected behavior)
- **Definitions & invariants** (cohort definitions, timestamps/timezones, “ALL records” definition)
- **Scope** (in / out)
- **Acceptance criteria** (explicit pass/fail bullets; no vague words)
- **Proof/QA plan** (commands + expected outputs)
- **Execution/Evidence gate** (mandatory if any backfill/script/run exists)

#### Hard anti-vagueness rules

Auto-block if any of these happen:
- “works”, “should”, “fix”, “handle”, “robust”, “fast”, “better” without measurable criteria.
- “Examples” where a complete list is required (e.g., “these are examples of statuses”).
  - Force the owner to provide the full list or explicitly approve a default allowlist/denylist.

### 2) Devil’s advocate + simplification (KISS + YAGNI)

You must propose:
- **Recommended minimal plan** (what we ship first, what we cut)
- **1–2 alternatives** with clear tradeoffs (risk/scope/time)
- **What can go wrong** (failure modes) + mitigations (rate limits, idempotence, timezones, partial runs)

If the recommended plan is not obviously minimal, it fails this step.

### 2.5) Codebase reuse scan (required)

Before freezing the EPIC approach or decomposing into tasks, scan the repo to find reuse candidates:
- Similar workflows/scripts/commands (cron runners, CLI scripts, backfill/migration patterns, common helpers).
- Concrete file paths + why they are relevant.
- If there are multiple plausible reuse paths, ask the owner to choose.

### 3) Freeze the PRD (convert to EPIC without creating a new issue)

Rewrite the EPIC body to be decision-complete using the template:
- Read: `TEMPLATES.md` (required).
- Update the EPIC issue body so it contains:
  - Goal
  - Context/links
  - Definitions/invariants
  - Scope (in/out)
  - Acceptance criteria
  - Proof/QA plan (commands + expected outputs)
  - Execution/Evidence gate (mandatory if applicable)
  - Task breakdown checklist (empty until tasks are created)

Then transition the EPIC state per your repo conventions.
- If you use labels/states, keep using them, but do not assume specific label names.
- The key requirement is: the EPIC/PRD must be clearly marked as “approved/spec locked” before decomposition.

### 4) Split into child TASK issues (delivery only happens here)

Create child TASK issues; every one must:
- Include `Epic: #<EPIC_NUMBER>` as the first line of the body.
- Be small enough to implement and QA in one pass.

#### Required next step (same agent)

Once the PRD/EPIC is frozen and the owner says “decompose now”, you must run skill:
- `epic-decompose`

Do not create child TASK issues inside this skill if the owner has not explicitly approved decomposition.

Required child TASK types (most EPICs will have all of these):
- **Implementation** tasks (code changes)
- **Verification/QA** tasks (audits, safety checks, regressions)
- **Execution: run end-to-end + post evidence** (mandatory final gate)

Each TASK issue body must include (use templates in `TEMPLATES.md`):
- Goal
- Acceptance criteria
- Test plan (commands + expected outputs)
- Rollout/execution steps (if any)
- Evidence to post before closing (mandatory for Execution/Evidence task)

### 5) “Solved = executed” enforcement (prevents hanging work)

Rules:
- EPIC closes only after the Execution/Evidence TASK is closed and includes the required evidence comment.
- If there is a backfill/script, “done” requires:
  - dry-run (sample)
  - full run across “ALL records”
  - evidence: totals, coverage %, mismatch/violations, and 3 real IDs proving correctness

### 6) Required communication hygiene (no silent decisions)

When the PRD is frozen:
- Post a short “spec locked” comment in the EPIC with:
  - the key decisions
  - key constraints
  - the final acceptance criteria list
  - links to all child TASK issues
