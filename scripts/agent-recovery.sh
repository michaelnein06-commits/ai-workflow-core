#!/usr/bin/env bash
# ============================================
# AGENT RECOVERY SYSTEM
# Erkennt inaktive Agents (>30 Min) und sendet
# Telegram-Alert mit interaktivem Recovery-Dialog
#
# Usage:
#   agent-recovery.sh              # Einmal prüfen
#   agent-recovery.sh --daemon     # Endlosschleife (alle 5 Min)
#   agent-recovery.sh --dry-run    # Nur prüfen, kein Alert
#
# Voraussetzungen:
#   - agent-status.json existiert
#   - notify-telegram.sh vorhanden
#   - tmux installiert
# ============================================

set -uo pipefail

# Konfiguration (überschreibbar via Env)
AGENT_STATUS_FILE="${AGENT_STATUS_FILE:-/root/share/05-system/agent-status.json}"
TELEGRAM="${TELEGRAM:-/home/micha/scripts/notify-telegram.sh}"
START_AGENTS="${START_AGENTS:-/home/micha/scripts/start-agents.sh}"
RECOVERY_LOG="${RECOVERY_LOG:-/home/micha/logs/agent-recovery.log}"
INACTIVITY_THRESHOLD="${INACTIVITY_THRESHOLD:-30}"  # Minuten
ALERT_COOLDOWN="${ALERT_COOLDOWN:-1800}"             # 30 Min zwischen Alerts pro Agent
RESPONSE_TIMEOUT="${RESPONSE_TIMEOUT:-3600}"          # 60 Min auf Antwort warten
POLL_INTERVAL="${POLL_INTERVAL:-300}"                 # 5 Min zwischen Checks im Daemon-Mode
ALERT_STATE_DIR="${ALERT_STATE_DIR:-/tmp/agent-recovery}"

# Telegram Bot Config (aus notify-telegram.sh lesen oder Env)
BOT_TOKEN="${BOT_TOKEN:-8723130551:AAHQGORmeFUFQJ2ZNWzNRegBBZpKIl_17dE}"
CHAT_ID="${CHAT_ID:-6097074401}"

DRY_RUN=false
DAEMON=false

# Agents die überwacht werden (orchestrator ist retired)
WATCHED_AGENTS=("dev1" "dev2" "qa" "merge")

# ── Logging ──
mkdir -p "$(dirname "$RECOVERY_LOG")" "$ALERT_STATE_DIR"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$RECOVERY_LOG"; }

# Log-Rotation (max 500 Zeilen)
rotate_log() {
    [ -f "$RECOVERY_LOG" ] && [ "$(wc -l < "$RECOVERY_LOG" 2>/dev/null || echo 0)" -gt 500 ] && \
        tail -200 "$RECOVERY_LOG" > "${RECOVERY_LOG}.tmp" && mv "${RECOVERY_LOG}.tmp" "$RECOVERY_LOG"
}

# ── Argument Parsing ──
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --daemon)  DAEMON=true ;;
    esac
done

# ── Prüfe ob Status-Datei existiert ──
check_status_file() {
    if [ ! -f "$AGENT_STATUS_FILE" ]; then
        log "FEHLER: agent-status.json nicht gefunden: $AGENT_STATUS_FILE"
        return 1
    fi
    return 0
}

# ── Inaktivitätszeit eines Agents in Minuten ──
get_inactive_minutes() {
    local agent="$1"
    python3 -c "
import json, sys, time
from datetime import datetime, timezone

with open('$AGENT_STATUS_FILE') as f:
    data = json.load(f)

agent_data = data.get('$agent', {})
updated = agent_data.get('updated', '')
status = agent_data.get('status', 'unknown')

# Idle Agents nicht als inaktiv melden
if status in ('idle', 'done', 'retired'):
    print('-1')
    sys.exit(0)

if not updated:
    print('9999')
    sys.exit(0)

try:
    # ISO 8601 Format
    ts = datetime.fromisoformat(updated.replace('Z', '+00:00'))
    now = datetime.now(timezone.utc)
    diff = (now - ts).total_seconds() / 60
    print(int(diff))
except Exception:
    print('9999')
" 2>/dev/null || echo "-1"
}

# ── Agent-Status lesen ──
get_agent_status() {
    local agent="$1"
    python3 -c "
import json
with open('$AGENT_STATUS_FILE') as f:
    data = json.load(f)
agent_data = data.get('$agent', {})
print(agent_data.get('status', 'unknown'))
" 2>/dev/null || echo "unknown"
}

# ── Agent-Task lesen ──
get_agent_task() {
    local agent="$1"
    python3 -c "
import json
with open('$AGENT_STATUS_FILE') as f:
    data = json.load(f)
agent_data = data.get('$agent', {})
print(agent_data.get('task', 'unbekannt'))
" 2>/dev/null || echo "unbekannt"
}

# ── tmux Session prüfen ──
is_session_alive() {
    local agent="$1"
    tmux has-session -t "$agent" 2>/dev/null
    return $?
}

# ── Recovery-Grund ermitteln ──
get_recovery_reason() {
    local agent="$1"
    local inactive_min="$2"

    # 1. tmux Session tot?
    if ! is_session_alive "$agent"; then
        echo "tmux_dead"
        return
    fi

    # 2. Auth-Token abgelaufen?
    local screen
    screen=$(tmux capture-pane -t "$agent" -p -S -20 2>/dev/null) || true
    if echo "$screen" | grep -qi "does not have access\|oauth.*revoked\|token.*revoked\|Please login\|sign in\|logged out\|unauthorized\|401"; then
        echo "auth_expired"
        return
    fi

    # 3. Agent stuck (Status nicht aktualisiert)
    echo "agent_stuck"
}

# ── Alert-Cooldown prüfen ──
should_alert() {
    local agent="$1"
    local state_file="${ALERT_STATE_DIR}/${agent}.alert"

    if [ ! -f "$state_file" ]; then
        return 0  # Kein vorheriger Alert
    fi

    local last_alert
    last_alert=$(stat -c %Y "$state_file" 2>/dev/null || echo 0)
    local now
    now=$(date +%s)
    local diff=$((now - last_alert))

    [ "$diff" -gt "$ALERT_COOLDOWN" ]
}

# ── Alert senden ──
send_alert() {
    local agent="$1"
    local reason="$2"
    local inactive_min="$3"
    local task="$4"

    local reason_text
    case "$reason" in
        tmux_dead)    reason_text="tmux Session gestorben" ;;
        auth_expired) reason_text="Auth-Token abgelaufen" ;;
        agent_stuck)  reason_text="Agent reagiert nicht (Status veraltet)" ;;
        *)            reason_text="Unbekannt ($reason)" ;;
    esac

    local message
    message="$(cat <<EOF
🚨 AGENT INAKTIV: ${agent}

⏱ Inaktiv seit: ${inactive_min} Min
🔍 Grund: ${reason_text}
📋 Task: ${task}

Was tun?
A = Auto-Restart (Session neustarten)
B = Manuell (ich kümmere mich selbst)
EOF
)"

    if $DRY_RUN; then
        echo "[DRY-RUN] Würde Alert senden für $agent:"
        echo "$message"
        log "DRY-RUN: Alert für $agent ($reason, ${inactive_min} Min inaktiv)"
        return 0
    fi

    "$TELEGRAM" "$message" 2>/dev/null
    touch "${ALERT_STATE_DIR}/${agent}.alert"
    # Speichere Kontext für Response-Handling
    echo "$agent|$reason|$(date +%s)" > "${ALERT_STATE_DIR}/${agent}.pending"
    log "ALERT gesendet: $agent ($reason, ${inactive_min} Min inaktiv, Task: $task)"
}

# ── Telegram-Updates lesen (auf Antwort warten) ──
check_telegram_response() {
    local agent="$1"
    local pending_file="${ALERT_STATE_DIR}/${agent}.pending"

    [ ! -f "$pending_file" ] && return 1

    local pending_data
    pending_data=$(cat "$pending_file")
    local alert_time
    alert_time=$(echo "$pending_data" | cut -d'|' -f3)
    local now
    now=$(date +%s)

    # Timeout prüfen
    if [ $((now - alert_time)) -gt "$RESPONSE_TIMEOUT" ]; then
        log "TIMEOUT: Keine Antwort für $agent nach ${RESPONSE_TIMEOUT}s"
        echo "timeout" > "${ALERT_STATE_DIR}/${agent}.result"
        rm -f "$pending_file"
        "$TELEGRAM" "⏰ Timeout für $agent Recovery. Keine Antwort nach 60 Min. Agent bleibt inaktiv." 2>/dev/null || true
        return 1
    fi

    # Letzte Telegram-Nachrichten lesen
    local updates
    updates=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates?offset=-5&limit=5" 2>/dev/null) || return 1

    # Suche nach A oder B Antwort nach dem Alert-Zeitpunkt
    local response
    response=$(python3 -c "
import json, sys

data = json.loads('''$updates''')
results = data.get('result', [])

for msg in reversed(results):
    message = msg.get('message', {})
    chat_id = str(message.get('chat', {}).get('id', ''))
    text = message.get('text', '').strip().upper()
    msg_date = message.get('date', 0)

    if chat_id == '$CHAT_ID' and msg_date >= $alert_time:
        if text in ('A', 'B'):
            print(text)
            sys.exit(0)

print('')
" 2>/dev/null) || return 1

    if [ -n "$response" ]; then
        echo "$response"
        return 0
    fi

    return 1
}

# ── Agent neustarten ──
restart_agent() {
    local agent="$1"
    local reason="$2"

    log "RESTART: $agent (Grund: $reason)"

    # Session beenden falls noch vorhanden
    tmux kill-session -t "$agent" 2>/dev/null || true
    sleep 2

    # Nur diese eine Session neustarten via start-agents.sh
    if [ -x "$START_AGENTS" ]; then
        "$START_AGENTS" >> "$RECOVERY_LOG" 2>&1
        sleep 3

        # Prüfe ob Session wieder läuft
        if is_session_alive "$agent"; then
            log "ERFOLG: $agent erfolgreich neugestartet"
            "$TELEGRAM" "✅ $agent erfolgreich neugestartet! Session läuft wieder." 2>/dev/null || true
            rm -f "${ALERT_STATE_DIR}/${agent}.pending" "${ALERT_STATE_DIR}/${agent}.alert"
            echo "success" > "${ALERT_STATE_DIR}/${agent}.result"
            return 0
        else
            log "FEHLER: $agent Neustart fehlgeschlagen"
            "$TELEGRAM" "❌ $agent Neustart fehlgeschlagen! Bitte manuell prüfen:
ssh vps-claude
tmux ls" 2>/dev/null || true
            echo "failed" > "${ALERT_STATE_DIR}/${agent}.result"
            return 1
        fi
    else
        log "FEHLER: start-agents.sh nicht gefunden: $START_AGENTS"
        "$TELEGRAM" "❌ start-agents.sh nicht gefunden. Kann $agent nicht neustarten." 2>/dev/null || true
        return 1
    fi
}

# ── Hauptlogik: Einmal prüfen ──
check_agents() {
    check_status_file || return 1
    rotate_log

    local alerts_sent=0

    for agent in "${WATCHED_AGENTS[@]}"; do
        local status
        status=$(get_agent_status "$agent")

        # Idle/done/retired Agents überspringen
        if [[ "$status" == "idle" || "$status" == "done" || "$status" == "retired" ]]; then
            continue
        fi

        local inactive_min
        inactive_min=$(get_inactive_minutes "$agent")

        # Fehler beim Lesen → überspringen
        [ "$inactive_min" -eq -1 ] 2>/dev/null && continue

        if [ "$inactive_min" -gt "$INACTIVITY_THRESHOLD" ]; then
            local reason
            reason=$(get_recovery_reason "$agent" "$inactive_min")
            local task
            task=$(get_agent_task "$agent")

            # Prüfe ob bereits ein ausstehender Alert existiert
            if [ -f "${ALERT_STATE_DIR}/${agent}.pending" ]; then
                # Auf Antwort prüfen
                local response
                response=$(check_telegram_response "$agent") || continue

                case "$response" in
                    A)
                        log "ANTWORT: Auto-Restart für $agent"
                        "$TELEGRAM" "🔄 Starte $agent neu..." 2>/dev/null || true
                        restart_agent "$agent" "$reason"
                        ;;
                    B)
                        log "ANTWORT: Manuelles Recovery für $agent"
                        "$TELEGRAM" "👍 OK, $agent bleibt dir überlassen." 2>/dev/null || true
                        rm -f "${ALERT_STATE_DIR}/${agent}.pending"
                        echo "manual" > "${ALERT_STATE_DIR}/${agent}.result"
                        ;;
                esac
                continue
            fi

            # Cooldown prüfen
            if should_alert "$agent"; then
                send_alert "$agent" "$reason" "$inactive_min" "$task"
                alerts_sent=$((alerts_sent + 1))
            fi
        fi
    done

    return 0
}

# ── Daemon Mode ──
run_daemon() {
    log "DAEMON gestartet (Intervall: ${POLL_INTERVAL}s, Threshold: ${INACTIVITY_THRESHOLD} Min)"
    while true; do
        check_agents
        sleep "$POLL_INTERVAL"
    done
}

# ── Ausführung ──
if $DAEMON; then
    run_daemon
else
    check_agents
fi
