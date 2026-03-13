#!/bin/bash
# ============================================
# WORKFLOW INBOX — Prüft ob Gary einen Auftrag hat
#
# Läuft als Cron jede Minute
# Prüft /root/share/workflow/inbox.md auf neue Inhalte
# Wenn ja: Sendet an Orchestrator tmux Session
# ============================================

set -euo pipefail

INBOX="/root/share/workflow/inbox.md"
LOG_FILE="/root/share/workflow/log.md"
PROCESSED_MARKER="/tmp/workflow-inbox-last"

LOCKFILE="/tmp/workflow-inbox.lock"
exec 200>"$LOCKFILE"
flock -n 200 || exit 0

# Inbox existiert und hat Inhalt?
[ -f "$INBOX" ] || exit 0
[ -s "$INBOX" ] || exit 0

# Schon verarbeitet? (Vergleich via md5)
CURRENT_HASH=$(md5sum "$INBOX" | cut -d' ' -f1)
LAST_HASH=""
[ -f "$PROCESSED_MARKER" ] && LAST_HASH=$(cat "$PROCESSED_MARKER")

[ "$CURRENT_HASH" = "$LAST_HASH" ] && exit 0

# Neuer Auftrag! An Orchestrator senden
if tmux has-session -t orchestrator 2>/dev/null; then
    # Inhalt der Inbox in den Orchestrator tippen
    CONTENT=$(cat "$INBOX")
    tmux send-keys -t orchestrator "Neuer Auftrag aus der Inbox:" Enter
    tmux send-keys -t orchestrator "cat /root/share/workflow/inbox.md" Enter

    echo "- **$(date -u '+%Y-%m-%dT%H:%M:%SZ')** | INBOX: Neuer Auftrag an Orchestrator gesendet" >> "$LOG_FILE"
else
    echo "- **$(date -u '+%Y-%m-%dT%H:%M:%SZ')** | INBOX: FEHLER — Orchestrator Session nicht gefunden!" >> "$LOG_FILE"
    /home/micha/scripts/notify-telegram.sh "Inbox hat Auftrag aber Orchestrator läuft nicht!" --silent 2>/dev/null || true
fi

# Als verarbeitet markieren
echo "$CURRENT_HASH" > "$PROCESSED_MARKER"
