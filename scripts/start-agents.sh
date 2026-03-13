#!/bin/bash
# ============================================
# START AGENTS — 5 tmux Sessions mit Claude Code
#
# Startet: orchestrator, dev1, dev2, qa, merge
# Jeder Agent läuft INTERAKTIV in seinem eigenen Verzeichnis
# mit CLAUDE.md als Rollenanweisung.
#
# Agents warten auf Aufgaben via tmux send-keys.
# ============================================

set -euo pipefail

AGENTS_DIR="/root/share/workflow/agents"
WORKFLOW_DIR="/root/share/workflow"

# Sicherstellen dass Verzeichnisse existieren
mkdir -p "$WORKFLOW_DIR/tasks"
[ -f "$WORKFLOW_DIR/status.json" ] || echo '{}' > "$WORKFLOW_DIR/status.json"
[ -f "$WORKFLOW_DIR/inbox.md" ] || touch "$WORKFLOW_DIR/inbox.md"
[ -f "$WORKFLOW_DIR/log.md" ] || touch "$WORKFLOW_DIR/log.md"

start_agent() {
    local name="$1"

    # Skip wenn Session schon läuft UND Claude aktiv ist
    if tmux has-session -t "$name" 2>/dev/null; then
        local pid
        pid=$(tmux display-message -t "$name" -p '#{pane_pid}' 2>/dev/null) || true
        local alive
        alive=$(ps --ppid "${pid:-0}" -o pid= 2>/dev/null | xargs -I{} ps -p {} -o comm= 2>/dev/null | grep -c claude 2>/dev/null) || true
        if [ "${alive:-0}" -gt 0 ]; then
            echo "[$name] Claude läuft bereits, überspringe"
            return 0
        fi
        # Session da aber Claude tot → Session killen und neu starten
        tmux kill-session -t "$name" 2>/dev/null || true
        sleep 1
    fi

    # CLAUDE.md muss existieren
    if [ ! -f "$AGENTS_DIR/$name/CLAUDE.md" ]; then
        echo "[$name] FEHLER: $AGENTS_DIR/$name/CLAUDE.md fehlt!"
        return 1
    fi

    # Neue tmux Session im Agent-Verzeichnis erstellen
    tmux new-session -d -s "$name" -c "$AGENTS_DIR/$name" -x 200 -y 50

    # Claude Code INTERAKTIV starten (liest CLAUDE.md automatisch)
    # CLAUDECODE= verhindert "nested session" Fehler
    tmux send-keys -t "$name" "CLAUDECODE= claude --dangerously-skip-permissions" Enter

    echo "[$name] Session gestartet (interaktiv)"
    sleep 2
}

echo "=== AI Workflow — Starte Agents ==="
echo "$(date '+%Y-%m-%d %H:%M:%S')"
echo ""

for name in orchestrator dev1 dev2 qa merge; do
    start_agent "$name"
done

echo ""
echo "=== Alle Agents gestartet ==="
echo "Prüfen: tmux ls"
echo "Verbinden: tmux attach -t <name>"
