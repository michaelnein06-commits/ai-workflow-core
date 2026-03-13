#!/bin/bash
# ============================================
# TOKEN GUARDIAN — Hält alles am Leben
# EIN Token für: Agents, Gary, CLI
# Läuft alle 2 Min via Cron (user micha)
#
# Proaktiver Refresh: Wenn Token < 2h verbleibt,
# wird ein harmloser Befehl an einen Agent gesendet.
# Claude Code refresht dann automatisch bei API-Call.
# Token wird außerdem zu NanoClaw synchronisiert.
# ============================================

set -euo pipefail

SCRIPTS="/home/micha/scripts"
LOG="/home/micha/logs/token-guardian.log"
CREDS="/home/micha/.claude/.credentials.json"
NANOCLAW_ENV="/root/nanoclaw/.env"
LOCKFILE="/tmp/token-guardian.lock"

exec 200>"$LOCKFILE"
flock -n 200 || exit 0
mkdir -p /home/micha/logs

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"; }

# Log-Rotation
[ -f "$LOG" ] && [ "$(wc -l < "$LOG" 2>/dev/null || echo 0)" -gt 500 ] && tail -200 "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"

# ── Token-Restzeit in Minuten ──
get_remaining_minutes() {
    python3 -c "
import json, time
with open('$CREDS') as f:
    d = json.load(f)
print(int((d['claudeAiOauth']['expiresAt']/1000) - time.time()) // 60)
" 2>/dev/null || echo "-1"
}

# ── NanoClaw Token synchen (KEIN Restart wenn nicht nötig) ──
sync_nanoclaw() {
    local token
    token=$(python3 -c "import json; print(json.load(open('$CREDS'))['claudeAiOauth']['accessToken'])" 2>/dev/null) || return 1
    local env_token
    env_token=$(sudo grep '^CLAUDE_CODE_OAUTH_TOKEN=' "$NANOCLAW_ENV" 2>/dev/null | cut -d'=' -f2-)

    if [ "$token" != "$env_token" ]; then
        sudo sed -i "s|^CLAUDE_CODE_OAUTH_TOKEN=.*|CLAUDE_CODE_OAUTH_TOKEN=$token|" "$NANOCLAW_ENV"
        # Nur Container stoppen+neustarten wenn einer läuft
        local running
        running=$(sudo docker ps --filter "name=nanoclaw-" -q 2>/dev/null)
        if [ -n "$running" ]; then
            sudo docker stop $running 2>/dev/null || true
            sleep 2
        fi
        sudo systemctl restart nanoclaw
        log "NanoClaw Token synchronisiert + neugestartet"
    fi
}

# ── tmux Sessions prüfen + reparieren ──
check_sessions() {
    local restarted=()
    for name in orchestrator dev1 dev2 qa merge; do
        if ! tmux has-session -t "$name" 2>/dev/null; then
            restarted+=("$name"); continue
        fi
        local pid
        pid=$(tmux display-message -t "$name" -p '#{pane_pid}' 2>/dev/null) || continue
        local alive
        alive=$(ps --ppid "$pid" -o pid= 2>/dev/null | xargs -I{} ps -p {} -o comm= 2>/dev/null | grep -c claude) || true
        [ "${alive:-0}" -eq 0 ] && restarted+=("$name") && continue

        local screen
        screen=$(tmux capture-pane -t "$name" -p -S -10 2>/dev/null) || continue
        echo "$screen" | grep -qi "does not have access\|oauth.*revoked\|token.*revoked\|Please login\|sign in\|logged out" && restarted+=("$name")
    done

    if [ ${#restarted[@]} -gt 0 ]; then
        for name in "${restarted[@]}"; do tmux kill-session -t "$name" 2>/dev/null || true; sleep 1; done
        "$SCRIPTS/start-agents.sh" >> "$LOG" 2>&1
        "$SCRIPTS/notify-telegram.sh" "🔄 Sessions neugestartet: ${restarted[*]}" --silent 2>/dev/null || true
        log "Sessions neugestartet: ${restarted[*]}"
    fi
}

# ════════════════════════════════════
# HAUPTLOGIK
# ════════════════════════════════════

remaining=$(get_remaining_minutes)
minute=$(date +%M)

# Status-Log alle 30 Min
[ "$((10#$minute % 30))" -lt 2 ] && log "OK: Token gültig noch ${remaining} Min"

# 1. NanoClaw Token IMMER synchen (fängt /login, manuellen Refresh, alles ab)
sync_nanoclaw

# 2. Proaktiver Token-Refresh: Wenn Token < 2h verbleibt, Agent aktivieren
# Claude Code refresht seinen Token AUTOMATISCH bei jeder Aktion.
# Wir triggern das durch einen harmlosen Befehl an einen idle Agent.
if [ "$remaining" -gt 0 ] && [ "$remaining" -le 120 ]; then
    REFRESH_LOCK="/tmp/token-refresh-trigger.lock"
    # Nur alle 30 Min triggern
    if [ ! -f "$REFRESH_LOCK" ] || [ "$(( $(date +%s) - $(stat -c %Y "$REFRESH_LOCK" 2>/dev/null || echo 0) ))" -gt 1800 ]; then
        # Sende harmlosen Befehl an Orchestrator → Claude Code macht API-Call → Token wird auto-refresht
        if tmux has-session -t orchestrator 2>/dev/null; then
            tmux send-keys -t orchestrator "echo 'Token-Refresh-Ping'" Enter 2>/dev/null || true
            touch "$REFRESH_LOCK"
            log "Token-Refresh getriggert (${remaining} Min verbleibend)"
        fi
    fi
fi

# 3. Wenn Token abgelaufen → Alarm
if [ "$remaining" -le 0 ]; then
    ALERT_LOCK="/tmp/token-guardian-alert.lock"
    if [ ! -f "$ALERT_LOCK" ] || [ "$(( $(date +%s) - $(stat -c %Y "$ALERT_LOCK" 2>/dev/null || echo 0) ))" -gt 600 ]; then
        "$SCRIPTS/notify-telegram.sh" "🚨 TOKEN ABGELAUFEN!
Token ist abgelaufen. Bitte einloggen:
ssh vps-claude && claude auth login
Sessions starten danach automatisch." 2>/dev/null || true
        touch "$ALERT_LOCK"
        log "TELEGRAM ALERT: Token abgelaufen (${remaining} Min)"
    fi
fi

# 3. Sessions prüfen (immer)
check_sessions
