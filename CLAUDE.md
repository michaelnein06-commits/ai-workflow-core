# AI Workflow Core

Multi-Agent Development System mit 5 Agents (Orchestrator, Dev1, Dev2, QA, Merge).

## Struktur
- `prompts/` — Agent-Prompts (werden als CLAUDE.md in tmux Sessions geladen)
- `scripts/` — Workflow-Scripts (Status, Heartbeat, Inbox, Start)
- `PRD.md` — Product Requirements Document

## Workflow-Daten (NICHT in diesem Repo)
- `/root/share/workflow/` — Task-Dateien, Status, Inbox, Log

## Wichtig
- Agents kommunizieren über Task-Dateien + Status-Script
- Orchestrator schreibt KEINEN Code
- Dev-Agents erstellen PRs, mergen NICHT
- QA ändert KEINEN Produktionscode
- Merge-Agent ändert KEINEN Code
