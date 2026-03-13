#!/bin/bash
# ============================================
# WORKFLOW CLEAR AGENT — Context eines Agents resetten
#
# Usage: workflow-clear-agent.sh <agent>
# Der Orchestrator ruft das auf NACHDEM er den Done-Status gelesen hat.
# Leert die Task-Datei und sendet /clear.
# ============================================

AGENT="${1:-}"
TASKS_DIR="/root/share/workflow/tasks"

if [ -z "$AGENT" ]; then
    echo "Usage: workflow-clear-agent.sh <agent>"
    exit 1
fi

if ! tmux has-session -t "$AGENT" 2>/dev/null; then
    echo "[$AGENT] Session existiert nicht"
    exit 1
fi

# Task-Datei leeren (verhindert dass Agent alten Auftrag liest)
TASK_FILE="$TASKS_DIR/${AGENT}-task.md"
if [ -f "$TASK_FILE" ]; then
    > "$TASK_FILE"
fi

# Warte bis Agent bereit ist (Eingabeaufforderung sichtbar, max 30s)
for i in $(seq 1 6); do
    SCREEN=$(tmux capture-pane -t "$AGENT" -p -S -3 2>/dev/null || true)
    if echo "$SCREEN" | grep -q "^❯ $"; then
        break
    fi
    sleep 5
done

# /clear senden
tmux send-keys -t "$AGENT" "/clear" Enter 2>/dev/null
echo "[$AGENT] Task + Context cleared"
