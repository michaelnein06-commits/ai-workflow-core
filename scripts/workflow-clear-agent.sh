#!/bin/bash
# ============================================
# WORKFLOW CLEAR AGENT — Context eines Agents resetten
#
# Usage: workflow-clear-agent.sh <agent>
# Der Orchestrator ruft das auf NACHDEM er den Done-Status gelesen hat.
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

# Warten bis der Agent seine Ausgabe fertig hat
sleep 5

# /clear senden
tmux send-keys -t "$AGENT" "/clear" Enter 2>/dev/null
echo "[$AGENT] Context cleared"
