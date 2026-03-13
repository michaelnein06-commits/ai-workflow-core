#!/bin/bash
# ============================================
# WORKFLOW HEARTBEAT — Prüft ob Agents leben
#
# Läuft als Cron alle 2 Minuten
# Prüft: tmux Session vorhanden + Claude Prozess aktiv
# Bei Timeout (>10 Min kein Status-Update): Alert
# ============================================

set -euo pipefail

STATUS_FILE="/root/share/workflow/status.json"
LOG_FILE="/root/share/workflow/log.md"
NOTIFY="/home/micha/scripts/notify-telegram.sh"
SCRIPTS="/home/micha/scripts"

LOCKFILE="/tmp/workflow-heartbeat.lock"
exec 200>"$LOCKFILE"
flock -n 200 || exit 0

AGENTS="orchestrator dev1 dev2 qa merge"
PROBLEMS=()
RESTARTED=()

for name in $AGENTS; do
    # 1. tmux Session vorhanden?
    if ! tmux has-session -t "$name" 2>/dev/null; then
        RESTARTED+=("$name")
        continue
    fi

    # 2. Claude Prozess aktiv?
    pid=$(tmux display-message -t "$name" -p '#{pane_pid}' 2>/dev/null) || continue
    alive=$(ps --ppid "$pid" -o pid= 2>/dev/null | xargs -I{} ps -p {} -o comm= 2>/dev/null | grep -c claude) || true
    if [ "${alive:-0}" -eq 0 ]; then
        RESTARTED+=("$name")
        continue
    fi

    # 3. Timeout-Check: Agent "working" seit >10 Min ohne Update?
    last_update=$(python3 -c "
import json, time
try:
    with open('$STATUS_FILE') as f:
        data = json.load(f)
    agent = data.get('$name', {})
    if agent.get('status') == 'working':
        from datetime import datetime
        updated = datetime.fromisoformat(agent['updated'].replace('Z', '+00:00'))
        age_min = (datetime.now(updated.tzinfo) - updated).total_seconds() / 60
        print(int(age_min))
    else:
        print(0)
except:
    print(0)
" 2>/dev/null) || last_update=0

    if [ "$last_update" -gt 10 ]; then
        PROBLEMS+=("$name: working seit ${last_update} Min ohne Update")
    fi
done

# Sessions neustarten wenn nötig
if [ ${#RESTARTED[@]} -gt 0 ]; then
    for name in "${RESTARTED[@]}"; do
        tmux kill-session -t "$name" 2>/dev/null || true
        sleep 1
    done

    "$SCRIPTS/start-agents.sh" 2>/dev/null || true

    msg="Agents neugestartet: ${RESTARTED[*]}"
    echo "- **$(date -u '+%Y-%m-%dT%H:%M:%SZ')** | HEARTBEAT: $msg" >> "$LOG_FILE"

    # Telegram NUR wenn 3x hintereinander neugestartet wurde (kein Spam)
    RESTART_COUNT_FILE="/tmp/heartbeat-restart-count"
    count=1
    if [ -f "$RESTART_COUNT_FILE" ]; then
        last_count=$(cat "$RESTART_COUNT_FILE" 2>/dev/null || echo 0)
        last_age=$(( $(date +%s) - $(stat -c %Y "$RESTART_COUNT_FILE" 2>/dev/null || echo 0) ))
        if [ "$last_age" -lt 600 ]; then
            count=$((last_count + 1))
        fi
    fi
    echo "$count" > "$RESTART_COUNT_FILE"

    if [ "$count" -ge 3 ]; then
        "$NOTIFY" "Agents crashen wiederholt: ${RESTARTED[*]} (${count}x in 10 Min)" --silent 2>/dev/null || true
        echo 0 > "$RESTART_COUNT_FILE"
    fi
fi

# Timeout-Probleme melden
if [ ${#PROBLEMS[@]} -gt 0 ]; then
    msg="Agent-Timeout: $(printf '%s, ' "${PROBLEMS[@]}")"
    echo "- **$(date -u '+%Y-%m-%dT%H:%M:%SZ')** | HEARTBEAT: $msg" >> "$LOG_FILE"

    # Nur alle 10 Min benachrichtigen (nicht spammen)
    ALERT_LOCK="/tmp/heartbeat-alert.lock"
    if [ ! -f "$ALERT_LOCK" ] || [ "$(( $(date +%s) - $(stat -c %Y "$ALERT_LOCK" 2>/dev/null || echo 0) ))" -gt 600 ]; then
        "$NOTIFY" "$msg" --silent 2>/dev/null || true
        touch "$ALERT_LOCK"
    fi
fi
