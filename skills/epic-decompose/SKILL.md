---
name: epic-decompose
description: Split an approved PRD/EPIC into child TASK issues (create tasks, link back to EPIC, ensure Execution/Proof task exists).
---

# EPIC Decompose (PRD/EPIC → child TASK issues)

Use this skill after the PRD/EPIC is decision-complete and the owner says “decompose now”.

## Cold-start warning (read this)

Assume the downstream dev/QA agents have **zero prior project context** and a **blank context window**.
The PRD/EPIC is the single source of truth, so each child TASK must be detailed enough that an agent can execute without asking questions.

## Non-negotiables

- Do not change requirements during decomposition. Only split delivery into child TASK issues.
- Every child TASK must include `Epic: #<EPIC_NUMBER>` as the first line of the body.
- EPICs are never closed by PRs. PRs close TASK issues only.
- Always include a final child TASK:
  - `Execution: run end-to-end + post evidence`
- If any real-world action is required (backfill, script run, data fix, rollout), the Execution task MUST require:
  - explicit record selection criteria (“ALL records” definition)
  - dry-run + full run instructions
  - safety caps + idempotency strategy
  - evidence format (totals, coverage %, mismatch/error totals, 3 concrete IDs)
  - post-run validation steps
  - rollback plan (and data implications)

## Guardrails

- Default to **2 tasks**: **1 Implementation** + **1 Execution**. If proposing more than 4 tasks, justify why and include a smaller alternative.
- Prefer 3–8 child TASK issues. If >8, propose an MVP cut first.
- Each TASK must be independently deliverable and QA-able in one pass.
- Labels for new TASKs:
  - `type:task`
  - `draft`

## Workflow

### 1) Preflight: load EPIC, read required docs, and confirm it’s ready

- Fetch EPIC title/body/labels.
- Confirm it’s labeled `type:epic`.
- Read required repo guidance (do not rely on memory):
  - the project’s docs/rules (examples: `README.md`, `CONTRIBUTING.md`, `AGENTS.md`, `docs/`)
  - and any area-specific docs for the EPIC’s “primary area” (API, data model, workers, UI, etc.)
- Confirm the EPIC contains:
  - Acceptance Criteria (checkboxes)
  - QA plan / proof plan
  - Execution / runbook content if any real-world action is required

If any of these are missing: STOP and return to the PRD/EPIC workflow.

### 2) Propose the child TASK list (before creating anything)

Output a proposed checklist with:
- Task titles
- 1-sentence purpose
- Which EPIC AC(s) it satisfies
- Notes on risk/scope

Then ask the owner:
- “Create these issues now? (yes/no)”

### 3) Create the TASK issues (only after explicit approval)

For each TASK:
- Create a GitHub issue titled `[TASK] ...`
- Add labels `type:task` + `draft`
- Body must start with:
  - `Epic: #<EPIC_NUMBER>`
- Include enough context for a cold-start agent:
  - Goal
  - Brief background (1–3 bullets copied/summarized from the EPIC)
  - Constraints / invariants (copied from the EPIC; include “do-not-change” list)
  - Approach (what to do; reference EPIC if unsure)
  - Reuse candidates (concrete file paths if known; otherwise instruct to search)
  - Acceptance criteria (subset mapped to EPIC ACs)
  - Test plan (commands + expected outputs)
  - Execution steps (if applicable)
  - Evidence to post before closing (mandatory for the Execution/Proof task)

If you are unsure about any detail, explicitly instruct the agent to re-read the EPIC and the routed docs before implementing.

### 4) Link tasks back to EPIC

Update the EPIC “Task breakdown” checklist to include links:
- `- [ ] #1234 Task: ...`
- ...
- `- [ ] #1239 Execution: run end-to-end + post evidence`

### 5) Final integrity check

Output:
- Final child issue list (links)
- Mapping: EPIC AC → child TASK(s) that prove it
- Reminder: EPIC is only “solved” after the Execution task evidence is posted
