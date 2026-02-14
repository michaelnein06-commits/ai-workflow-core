---
name: agent-learnings
description: Log durable agent learnings as JSON entries for reuse across tasks.
---

# Agent Learnings (Repo-local)

Use this skill whenever you discover durable institutional knowledge while working on this repo.

## Core rules (must follow)

- **Log immediately on discovery** — do not wait until the end of the task.
- **Institutional value only** — capture owner preferences, decision patterns, architecture rationale, and hard-won lessons.
- **Quality over volume** — **1 good preference > 5 CLI gotchas**.
- **Soft cap** — aim for **~5 entries per TASK**. If you need more, consolidate.
- **Docs-first migration** — if a learning is project-specific and should be onboarding guidance, migrate it into `docs/` and avoid duplicating trivia here.

## Where to write

- Create a new `*.json` file under: `.codex/agent_learnings/entries/`.
- Use a short, unique filename (timestamp + topic is fine).

## Required JSON fields

```json
{
  "ts_utc": "2026-02-04T18:12:34Z",
  "category": "owner-preference|decision-pattern|architecture|communication|workflow|anti-pattern|technical-gotcha",
  "text": "2–5 lines. Explain the insight, why it matters, and the preferred action."
}
```

### Optional context

- `issue`: issue link or id (for traceability when useful)
- `pointers`: array of strings (file paths, commands, PR/issue links)

## Good entry examples (target quality)

```json
{
  "ts_utc": "2026-02-07T11:00:00Z",
  "category": "owner-preference",
  "text": "Owner prefers the smallest safe diff that proves behavior end-to-end.\nWhen a change can be split, ship the risk-reducing piece first.\nThis keeps review latency low and rollback simple."
}
```

```json
{
  "ts_utc": "2026-02-07T11:05:00Z",
  "category": "decision-pattern",
  "text": "When choosing between hidden script filters vs a visible, shareable query (view/dashboard), default to the visible option.\nIt makes state understandable to humans and reduces magic.\nUse script filters only for narrow per-run constraints."
}
```

```json
{
  "ts_utc": "2026-02-07T11:10:00Z",
  "category": "anti-pattern",
  "text": "Do not mutate historical inputs that would change past results.\nIf a previous run exists, prefer creating a new variant/version instead.\nThis preserves auditability and makes rollbacks possible."
}
```

## Validation (optional)
- Validate JSON with a quick check (pick one):
  - `python3 -m json.tool <file>`
  - `jq . <file>`
