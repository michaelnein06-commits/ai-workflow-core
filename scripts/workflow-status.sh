#!/bin/bash
# ============================================
# WORKFLOW STATUS — Agents melden ihren Status
#
# Usage: workflow-status.sh <agent> <status> "beschreibung"
# Beispiel: workflow-status.sh dev1 done "PR #12 erstellt"
#
# Agents: orchestrator, dev1, dev2, qa, merge
# Status: idle, working, done, blocked, failed
# ============================================

set -euo pipefail

STATUS_FILE="/root/share/workflow/status.json"
LOG_FILE="/root/share/workflow/log.md"

AGENT="${1:-}"
STATUS="${2:-}"
MESSAGE="${3:-}"

if [ -z "$AGENT" ] || [ -z "$STATUS" ]; then
    echo "Usage: workflow-status.sh <agent> <status> [message]"
    echo "Agents: orchestrator, dev1, dev2, qa, merge"
    echo "Status: idle, working, done, blocked, failed"
    exit 1
fi

# Validierung
VALID_AGENTS="orchestrator dev1 dev2 qa merge"
VALID_STATUS="idle working done blocked failed"

if ! echo "$VALID_AGENTS" | grep -qw "$AGENT"; then
    echo "Fehler: Unbekannter Agent '$AGENT'"
    exit 1
fi

if ! echo "$VALID_STATUS" | grep -qw "$STATUS"; then
    echo "Fehler: Unbekannter Status '$STATUS'"
    exit 1
fi

TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

# Status-Datei atomar updaten
python3 -c "
import json, sys

f = '$STATUS_FILE'
try:
    with open(f) as fh:
        data = json.load(fh)
except:
    data = {}

data['$AGENT'] = {
    'status': '$STATUS',
    'message': '''$MESSAGE''',
    'updated': '$TIMESTAMP'
}

with open(f, 'w') as fh:
    json.dump(data, fh, indent=2)
"

# Log-Eintrag
echo "- **$TIMESTAMP** | \`$AGENT\` → **$STATUS**: $MESSAGE" >> "$LOG_FILE"

echo "[$AGENT] Status: $STATUS — $MESSAGE"

# Telegram-Benachrichtigung bei jedem Statuswechsel
NOTIFY="/home/micha/scripts/notify-telegram.sh"
if [ -f "$NOTIFY" ]; then
    EMOJI=""
    case "$STATUS" in
        working) EMOJI="🔄" ;;
        done)    EMOJI="✅" ;;
        blocked) EMOJI="🚫" ;;
        failed)  EMOJI="❌" ;;
        idle)    EMOJI="💤" ;;
    esac

    # Agent-Namen lesbarer machen
    DISPLAY_NAME="$AGENT"
    case "$AGENT" in
        orchestrator) DISPLAY_NAME="Orchestrator" ;;
        dev1)         DISPLAY_NAME="Dev1" ;;
        dev2)         DISPLAY_NAME="Dev2" ;;
        qa)           DISPLAY_NAME="QA" ;;
        merge)        DISPLAY_NAME="Merge" ;;
    esac

    TG_MSG="${EMOJI} <b>${DISPLAY_NAME}</b> → ${STATUS}
${MESSAGE}"

    # idle = kein Telegram, working = silent, rest = normal
    if [ "$STATUS" != "idle" ]; then
        if [ "$STATUS" = "working" ]; then
            "$NOTIFY" "$TG_MSG" --silent 2>/dev/null &
        else
            "$NOTIFY" "$TG_MSG" 2>/dev/null &
        fi
    fi
fi
