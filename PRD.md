# PRD: AI Workflow Core — Multi-Agent Development System

**Version**: 2.0 (Neuaufbau)
**Status**: DRAFT — Review durch Micha
**Datum**: 2026-03-13

---

## 1. Problem

Das alte Multi-Agent-System war fragil, unübersichtlich und hat Spam produziert:
- Agents haben sich aufgehängt oder an falschen Dingen gearbeitet
- Telegram wurde mit Status-Updates alle 2 Min geflutet
- Kein klarer Kommunikationsweg zwischen Agents
- Kein Heartbeat (Agents liefen 10+ Min ohne Ergebnis, keiner hat es gemerkt)
- Orchestrator war ein starres Bash-Script
- Gary konnte keine sinnvollen Rückfragen stellen

## 2. Ziel

Ein **robustes, leanes Multi-Agent-System** das:
- Jedes Coding-Projekt durch den gleichen Qualitätsprozess führt
- Über Telegram (Gary) ODER Terminal steuerbar ist
- Nur relevante Nachrichten schickt (Task fertig, Fehler, Rückfrage)
- Sich selbst überwacht (Heartbeat, Timeout-Recovery)
- Sauber in 5+1 Panels sichtbar ist (Warp)
- Für beliebige Projekte funktioniert (nicht nur ein Repo)

## 3. Architektur

```
┌───────────────────────────────────────────────────┐
│                    MICHA                           │
│          Telegram (Gary) oder Terminal (SSH)       │
└──────────────────────┬────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────┐
│          ORCHESTRATOR (tmux Panel)                │
│          Claude Code — "Der Produktmanager"       │
│                                                   │
│  Empfängt Aufträge → PRD/Rückfragen →             │
│  Tasks verteilen → Ergebnisse prüfen →            │
│  Status an Micha melden                           │
└──────┬──────────────────┬────────────────────────┘
       │                  │
       ▼                  ▼
┌────────────┐    ┌────────────┐
│   DEV 1    │    │   DEV 2    │
│ Senior Dev │    │ Senior Dev │
│ Implement  │    │ Implement  │
│ + Tests    │    │ + Tests    │
│ + PR       │    │ + PR       │
└─────┬──────┘    └──────┬─────┘
      │                  │
      └────────┬─────────┘
               ▼
┌──────────────────────────┐
│          QA              │
│    QA-Ingenieur          │
│    Review + Tests        │
│    PASS → Merge          │
│    FAIL → Orchestrator   │
└──────────┬───────────────┘
           ▼
┌──────────────────────────┐
│         MERGE            │
│    Release Manager       │
│    PR merge + Cleanup    │
│    → Orchestrator meldet │
└──────────────────────────┘
```

## 4. Agenten-Rollen

### 4.1 Orchestrator — "Der Produktmanager"
- **Persönlichkeit**: Strategisch, strukturiert, fragt lieber einmal zu viel
- **Aufgabe**: Plant, verteilt, überwacht, kommuniziert mit Micha
- **Darf**: Aufträge vergeben, Status abfragen, Telegram senden, Rückfragen stellen
- **Darf NICHT**: Code schreiben, Tests ausführen, PRs erstellen
- **PRD-Phase**: Analysiert Auftrag, stellt Rückfragen bis Clarity Score ≥ 90, erstellt Tasks
- **Kommunikation**:
  - Empfängt Aufträge via Task-Datei (von Gary) ODER direkte Terminal-Eingabe
  - Sendet Updates an Micha via notify-telegram.sh
  - Delegiert an Dev/QA/Merge via Task-Dateien + tmux send-keys

### 4.2 Dev Agent 1 & 2 — "Die Senior Developer"
- **Persönlichkeit**: Fokussiert, pragmatisch, 80/20 Prinzip, schreibt immer Tests
- **Aufgabe**: Implementiert Features, schreibt Tests, erstellt PRs
- **Darf**: Code schreiben, Tests schreiben, git commit/push, PR erstellen
- **Darf NICHT**: PRs mergen, Issues schließen, andere Agents steuern
- **Arbeiten immer an verschiedenen Tasks** (nie am gleichen)
- **Bei Dependencies**: Nur einer arbeitet, der andere wartet

### 4.3 QA Agent — "Der QA-Ingenieur"
- **Persönlichkeit**: Kritisch, gründlich, sucht aktiv nach Fehlern, kein Bias
- **Aufgabe**: Code Review, Tests ausführen, Edge Cases prüfen
- **Darf**: Tests schreiben/erweitern, Bugs dokumentieren, PASS/FAIL entscheiden
- **Darf NICHT**: Produktionscode ändern, PRs mergen
- **Output**: Klarer PASS oder FAIL mit Begründung
  - PASS → weiter an Merge
  - FAIL → zurück an Orchestrator mit konkreten Fehlerberichten → Dev bekommt es erneut

### 4.4 Merge Agent — "Der Release Manager"
- **Persönlichkeit**: Vorsichtig, prüft CI-Status, räumt auf
- **Aufgabe**: PR mergen, Branch löschen, Issue schließen
- **Darf**: gh pr merge (squash), git branch delete, gh issue close
- **Darf NICHT**: Code ändern, neue Commits machen

## 5. Kommunikation zwischen Agents

### 5.1 Task-Dateien (Orchestrator → Agent)
```
/root/share/workflow/tasks/dev1-task.md
/root/share/workflow/tasks/dev2-task.md
/root/share/workflow/tasks/qa-task.md
/root/share/workflow/tasks/merge-task.md
```

Beispiel Task-Datei:
```markdown
# Task: Implementiere Issue #5 — Login Page

## Repo
/root/projects/my-project

## Branch
feature/issue-5

## Akzeptanzkriterien
- Login-Formular mit Email + Passwort
- Validierung der Eingaben
- Tests für Happy Path + Error Cases

## Wenn fertig
1. PR erstellen: gh pr create --title "feat: Login Page" --body "Fixes #5"
2. Status melden: workflow-status dev1 done "PR #X erstellt für Issue #5"
```

### 5.2 Status-Meldungen (Agent → Orchestrator)
Jeder Agent meldet seinen Status über ein Script:
```bash
workflow-status dev1 done "PR #12 erstellt für Issue #5"
workflow-status qa fail "3 Tests fehlgeschlagen, siehe PR-Kommentar"
workflow-status dev1 working "Implementiere Login-Formular"
```

Status-Datei: `/root/share/workflow/status.json`

### 5.3 Telegram (Orchestrator → Micha)
**Nur bei diesen Events:**
- Neuer Auftrag empfangen + Rückfragen an Micha
- Dev fertig (PR erstellt)
- QA PASS oder FAIL
- Merge fertig (Issue geschlossen)
- Fehler/Timeout eines Agents
- Rückfrage die Michas Eingabe braucht

**NICHT bei:**
- Agent hat angefangen zu arbeiten
- Zwischenstände
- Regelmäßige Status-Polls

### 5.4 Heartbeat
- Jeder Agent updated Status mindestens alle 5 Min
- Wenn Agent > 10 Min keinen Update macht:
  1. Heartbeat-Script prüft tmux Pane
  2. Falls gehangen → Session neustarten, Task erneut zuweisen
  3. Micha wird benachrichtigt

## 6. Workflow-Modi

### 6.1 Vollständig (Features/Epics)
```
Auftrag → PRD/Rückfragen (Clarity ≥ 90) → Tasks → Dev → QA → Merge → Fertig
```

### 6.2 Quick-Fix (kleine Bugs/Tweaks)
```
Auftrag → kurze Rückfrage → Dev direkt → QA (schnell) → Merge
```
Orchestrator entscheidet: < 30 Min Arbeit + klare Anforderung = Quick-Fix.

### 6.3 Nur Planung
```
Auftrag → PRD erstellen → Rückfragen → Micha approved → Stop
```
Implementation startet erst wenn Micha "los" sagt.

## 7. Eingabewege

### 7.1 Telegram (über Gary)
```
Micha → Gary: "Ich brauche eine REST-API für User-Management"
  → Gary schreibt in /root/share/workflow/inbox.md
  → Inbox-Script triggert Orchestrator
  → Rückfragen gehen über Telegram
  → Antworten kommen über Telegram zurück
```

### 7.2 Terminal (Orchestrator-Panel direkt)
```
Micha tippt direkt im Orchestrator tmux Panel
  → Orchestrator startet sofort
  → Rückfragen + Antworten direkt im Panel
```

## 8. Dateistruktur

```
/root/share/workflow/                  ← Zentrale Workflow-Daten
├── inbox.md                           ← Neue Aufträge (von Gary)
├── status.json                        ← Agent-Status
├── tasks/                             ← Aktive Task-Dateien
│   ├── dev1-task.md
│   ├── dev2-task.md
│   ├── qa-task.md
│   └── merge-task.md
└── log.md                             ← Workflow-Log

/root/projects/ai-workflow-core/       ← Dieses Repo (Code)
├── scripts/
│   ├── start-agents.sh                ← 5 tmux Sessions starten
│   ├── workflow-status.sh             ← Status melden (Agents rufen das auf)
│   ├── workflow-heartbeat.sh          ← Heartbeat-Prüfung (Cron)
│   └── workflow-inbox.sh             ← Inbox → Orchestrator triggern (Cron)
├── prompts/
│   ├── orchestrator.md                ← CLAUDE.md für Orchestrator
│   ├── developer.md                   ← CLAUDE.md für Dev1/Dev2
│   ├── qa.md                          ← CLAUDE.md für QA
│   └── merge.md                       ← CLAUDE.md für Merge
├── CLAUDE.md
├── PRD.md                             ← Diese Datei
└── README.md

/home/micha/scripts/                   ← Symlinks
├── start-agents.sh → ai-workflow-core/scripts/...
├── workflow-status.sh → ...
├── workflow-heartbeat.sh → ...
└── workflow-inbox.sh → ...
```

## 9. Cron-Jobs (zusätzlich zu bestehenden)

```bash
# Agent Sessions nach Reboot
@reboot sleep 10 && /home/micha/scripts/start-agents.sh

# Heartbeat: Prüft ob Agents leben (alle 2 Min)
*/2 * * * * /home/micha/scripts/workflow-heartbeat.sh

# Inbox: Prüft ob Gary einen Auftrag hat (jede Minute)
* * * * * /home/micha/scripts/workflow-inbox.sh
```

## 10. Warp Layout (5+1)

```
┌────────────────────┬────────────────────┬──────────────────┐
│   ORCHESTRATOR     │     DEV 1          │    DEV 2         │
│   (lila)           │     (orange)       │    (gelb)        │
├────────────────────┼────────────────────┼──────────────────┤
│      QA            │     MERGE          │   DASHBOARD      │
│      (grün)        │     (blau)         │   (status.json)  │
└────────────────────┴────────────────────┴──────────────────┘
```

## 11. Außerhalb Scope V1

- Automatisches Starten bei GitHub Issue Push
- Mehrere Projekte gleichzeitig bearbeiten
- Skill-Loop / Self-Improver Integration
- Voice/Bild Support für Gary
- Automatische Git Worktree Verwaltung (manuell erstmal)

## 12. Erfolgskriterien

- [ ] Auftrag über Telegram empfangen + verarbeiten
- [ ] Auftrag über Terminal empfangen + verarbeiten
- [ ] PRD-Phase mit Rückfragen (Clarity ≥ 90)
- [ ] Dev1/Dev2 arbeiten parallel an verschiedenen Tasks
- [ ] QA prüft und gibt PASS/FAIL
- [ ] Bei FAIL: automatisch zurück → Dev → QA (Loop)
- [ ] Merge macht sauberen Squash-Merge + Cleanup
- [ ] Telegram nur bei relevanten Events
- [ ] Heartbeat erkennt + recovered hängende Agents
- [ ] Kompletter Feature-Durchlauf in < 30 Min
- [ ] System überlebt VPS-Reboot
- [ ] Warp 5+1 Layout zeigt alles live
