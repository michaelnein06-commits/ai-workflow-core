# PRD: ai-workflow-core
**Erstellt:** 2026-03-13
**Clarity Score:** 93/100
**Status:** EINGEFROREN — bereit zur Implementierung

## 1. Problem / Kontext

Der bestehende AI-Coding-Workflow (5-Agenten-System) läuft auf dem VPS, ist aber fragil:
- Wenn eine tmux Session stirbt: kein Auto-Recovery
- Kein einheitlicher Projekt-Start (jedes Mal manuell)
- Dokumentation passiert unregelmäßig
- Kein tägliches Monitoring / Health-Check

## 2. Ziele

1. Robustheit und Recovery: Workflow erkennt Probleme selbst und meldet sie
2. Neues Projekt starten: 1-Befehl-Wizard der alles aufsetzt

## 3. Deliverables (MVP)

### workflow-init.sh
- Interaktiver Wizard (Terminal + Telegram via Garry)
- PRD-Session IMMER zuerst (Garry als Sparring-Partner)
- Erstellt: GitHub Repo, CLAUDE.md, tmux Sessions, worktree Struktur

### workflow-doctor.sh
Checks:
- Claude API erreichbar
- Alle 5 tmux Sessions laufen (orchestrator, dev1, dev2, qa, merge)
- agent-status.json nicht veraltet (< 2h)
- GitHub Token gültig
- Google OAuth Token gültig
Reporting: Täglicher Telegram-Report, Report-first dann optional Auto-Fix

### Recovery-System
- Trigger: Agent inaktiv > 30 Min
- Ablauf: Telegram-Alert, auf Antwort warten, Empfehlung folgen

### Generic CLAUDE.md Templates
- orchestrator-CLAUDE.md, dev-CLAUDE.md, qa-CLAUDE.md, merge-CLAUDE.md

### Tägliche Auto-Doku
- Garry committed täglich abends DAILY-LOG-YYYY-MM-DD.md
- Cron: täglich 21:00

### Gary Skill
- Telegram: "init projekt", "doctor check", "workflow status"

## 4. Tech Stack

- Bash (Shell Scripts)
- Markdown
- tmux (5 Sessions)
- Telegram (notify-telegram.sh)
- GitHub Issues + PRs

## 5. Ausgeschlossen

- Kein Web-UI / Dashboard
- Keine Datenbank
- MVP = Shell + Markdown + Tmux

## 6. Akzeptanzkriterien

1. workflow-init.sh startet Projekt in < 2 Min
2. workflow-doctor.sh Report in < 30s, alle 5 Checks
3. Täglicher Telegram-Report täglich 08:00
4. Garry committed täglich abends Log-Commit
5. Recovery-Alert bei > 30 Min Inaktivität
6. Alle Scripts: Happy-Path + 3 Negativ-Tests

## 7. Repo

- Fork von: nathnotifia/ai-coding-workflow
- Neues Repo: michaelnein06-commits/ai-workflow-core
- Lokal: /root/projects/ai-workflow-core/
