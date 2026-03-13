#!/bin/bash
# ============================================
# START AGENTS — 5 tmux Sessions mit Claude Code
#
# Startet: orchestrator, dev1, dev2, qa, merge
# Jeder Agent bekommt seinen eigenen Prompt als CLAUDE.md
# ============================================

set -euo pipefail

PROMPTS_DIR="/root/projects/ai-workflow-core/prompts"
WORKFLOW_DIR="/root/share/workflow"
TMP_DIR="/tmp/workflow-prompts"

# Sicherstellen dass Verzeichnisse existieren
mkdir -p "$WORKFLOW_DIR/tasks" "$TMP_DIR"
[ -f "$WORKFLOW_DIR/status.json" ] || echo '{}' > "$WORKFLOW_DIR/status.json"
[ -f "$WORKFLOW_DIR/inbox.md" ] || touch "$WORKFLOW_DIR/inbox.md"
[ -f "$WORKFLOW_DIR/log.md" ] || touch "$WORKFLOW_DIR/log.md"

# Agent-Definitionen: name → prompt-datei
declare -A AGENTS=(
    [orchestrator]="orchestrator.md"
    [dev1]="developer.md"
    [dev2]="developer.md"
    [qa]="qa.md"
    [merge]="merge.md"
)

start_agent() {
    local name="$1"
    local prompt_file="$2"

    # Skip wenn Session schon läuft
    if tmux has-session -t "$name" 2>/dev/null; then
        echo "[$name] Session existiert bereits, überspringe"
        return 0
    fi

    # Prompt-Datei vorbereiten (Dev-Agents: DEV_NAME ersetzen)
    local tmp_prompt="$TMP_DIR/${name}-prompt.md"
    if [ "$name" = "dev1" ] || [ "$name" = "dev2" ]; then
        sed "s/DEV_NAME/$name/g" "$PROMPTS_DIR/$prompt_file" > "$tmp_prompt"
    else
        cp "$PROMPTS_DIR/$prompt_file" "$tmp_prompt"
    fi

    # Neue tmux Session erstellen
    tmux new-session -d -s "$name" -x 200 -y 50

    # Claude Code starten mit Prompt aus Datei
    # CLAUDECODE= verhindert "nested session" Fehler
    tmux send-keys -t "$name" "CLAUDECODE= claude --dangerously-skip-permissions -p \"\$(cat $tmp_prompt)\"" Enter

    echo "[$name] Session gestartet"
    sleep 2
}

echo "=== AI Workflow — Starte Agents ==="
echo "$(date '+%Y-%m-%d %H:%M:%S')"
echo ""

for name in orchestrator dev1 dev2 qa merge; do
    start_agent "$name" "${AGENTS[$name]}"
done

echo ""
echo "=== Alle Agents gestartet ==="
echo "Prüfen: tmux ls"
echo "Verbinden: tmux attach -t <name>"
