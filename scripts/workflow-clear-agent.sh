#!/bin/bash
# ============================================
# WORKFLOW CLEAR AGENT — Context eines Agents resetten
#
# Usage: workflow-clear-agent.sh <agent>
# Der Orchestrator ruft das auf NACHDEM er den Done-Status gelesen hat.
# Setzt den Agent-Status auf idle und sendet /clear.
# ============================================

AGENT="${1:-}"

if [ -z "$AGENT" ]; then
    echo "Usage: workflow-clear-agent.sh <agent>"
    exit 1
fi

if ! tmux has-session -t "$AGENT" 2>/dev/null; then
    echo "[$AGENT] Session existiert nicht"
    exit 1
fi

# Prüfe ob Agent gerade noch arbeitet (Bash-Befehl läuft)
# Warte bis die Eingabeaufforderung erscheint (max 30s)
for i in $(seq 1 6); do
    SCREEN=$(tmux capture-pane -t "$AGENT" -p -S -3 2>/dev/null || true)
    if echo "$SCREEN" | grep -q "^❯ $"; then
        break
    fi
    sleep 5
done

# /clear senden
tmux send-keys -t "$AGENT" "/clear" Enter 2>/dev/null
echo "[$AGENT] Context cleared"
