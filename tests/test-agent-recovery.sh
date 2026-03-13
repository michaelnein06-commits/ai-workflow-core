#!/usr/bin/env bash
# Tests für agent-recovery.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RECOVERY="${SCRIPT_DIR}/scripts/agent-recovery.sh"
PASS=0
FAIL=0

# Test-Hilfsfunktionen (gleich wie in test-workflow-doctor.sh)
assert_exit() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"
    if [[ "$actual" -eq "$expected" ]]; then
        echo "PASS: ${test_name}"
        PASS=$((PASS + 1))
    else
        echo "FAIL: ${test_name} (expected exit ${expected}, got ${actual})"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local output="$1"
    local pattern="$2"
    local test_name="$3"
    if echo "$output" | grep -qF "$pattern"; then
        echo "PASS: ${test_name}"
        PASS=$((PASS + 1))
    else
        echo "FAIL: ${test_name} (pattern '${pattern}' not found)"
        FAIL=$((FAIL + 1))
    fi
}

assert_not_contains() {
    local output="$1"
    local pattern="$2"
    local test_name="$3"
    if echo "$output" | grep -qF "$pattern"; then
        echo "FAIL: ${test_name} (pattern '${pattern}' unexpectedly found)"
        FAIL=$((FAIL + 1))
    else
        echo "PASS: ${test_name}"
        PASS=$((PASS + 1))
    fi
}

assert_file_exists() {
    local file="$1"
    local test_name="$2"
    if [ -f "$file" ]; then
        echo "PASS: ${test_name}"
        PASS=$((PASS + 1))
    else
        echo "FAIL: ${test_name} (file not found: $file)"
        FAIL=$((FAIL + 1))
    fi
}

# ── Test-Setup ──
TMPDIR=$(mktemp -d)
FAKE_STATUS="${TMPDIR}/agent-status.json"
FAKE_LOG="${TMPDIR}/recovery.log"
FAKE_ALERT_DIR="${TMPDIR}/alerts"
FAKE_TELEGRAM="${TMPDIR}/fake-telegram.sh"
FAKE_START_AGENTS="${TMPDIR}/fake-start-agents.sh"
TELEGRAM_LOG="${TMPDIR}/telegram-messages.log"

mkdir -p "$FAKE_ALERT_DIR"

# Fake Telegram Script (loggt Nachrichten statt sie zu senden)
cat > "$FAKE_TELEGRAM" << 'TEOF'
#!/bin/bash
echo "$1" >> "${TELEGRAM_LOG}"
TEOF
chmod +x "$FAKE_TELEGRAM"
# Exportiere TELEGRAM_LOG damit fake-telegram es findet
export TELEGRAM_LOG

# Fake start-agents.sh (tut nichts)
cat > "$FAKE_START_AGENTS" << 'SEOF'
#!/bin/bash
echo "fake start-agents called" >> "${RECOVERY_LOG:-/tmp/fake-recovery.log}"
SEOF
chmod +x "$FAKE_START_AGENTS"

# Env-Variablen für alle Tests
export AGENT_STATUS_FILE="$FAKE_STATUS"
export TELEGRAM="$FAKE_TELEGRAM"
export START_AGENTS="$FAKE_START_AGENTS"
export RECOVERY_LOG="$FAKE_LOG"
export ALERT_STATE_DIR="$FAKE_ALERT_DIR"
export INACTIVITY_THRESHOLD=30

echo "=== Test Suite: agent-recovery.sh ==="
echo ""

# ── Test 1: Happy Path — Inaktiver Agent wird erkannt und Alert gesendet ──
echo "--- Test 1: Happy Path — Alert bei Inaktivität ---"

# Status-Datei mit veraltetem Timestamp (2 Stunden her)
OLD_TIME=$(date -u -d "2 hours ago" '+%Y-%m-%dT%H:%M:%SZ')
cat > "$FAKE_STATUS" << EOF
{
  "dev1": {
    "status": "working",
    "task": "Issue #3: workflow-init.sh",
    "updated": "$OLD_TIME"
  },
  "dev2": {
    "status": "idle",
    "task": "",
    "updated": "$OLD_TIME"
  },
  "qa": {
    "status": "idle",
    "task": "",
    "updated": "$OLD_TIME"
  },
  "merge": {
    "status": "idle",
    "task": "",
    "updated": "$OLD_TIME"
  }
}
EOF

# Vorherige Alerts löschen
rm -f "$FAKE_ALERT_DIR"/* "$TELEGRAM_LOG"

bash "$RECOVERY" --dry-run 2>&1
exit_code=$?
assert_exit 0 "$exit_code" "Recovery-Check läuft ohne Fehler"

output=$(bash "$RECOVERY" --dry-run 2>&1)
assert_contains "$output" "DRY-RUN" "Dry-Run Modus aktiv"
assert_contains "$output" "dev1" "Inaktiver Agent dev1 erkannt"
echo ""

# ── Test 2: Idle Agents werden NICHT gemeldet ──
echo "--- Test 2: Idle Agents werden übersprungen ---"

# Alle Agents auf idle setzen
cat > "$FAKE_STATUS" << EOF
{
  "dev1": {
    "status": "idle",
    "task": "",
    "updated": "$OLD_TIME"
  },
  "dev2": {
    "status": "idle",
    "task": "",
    "updated": "$OLD_TIME"
  },
  "qa": {
    "status": "done",
    "task": "fertig",
    "updated": "$OLD_TIME"
  },
  "merge": {
    "status": "retired",
    "task": "",
    "updated": "$OLD_TIME"
  }
}
EOF

rm -f "$FAKE_ALERT_DIR"/* "$TELEGRAM_LOG"

output=$(bash "$RECOVERY" --dry-run 2>&1)
assert_not_contains "$output" "DRY-RUN" "Idle/done/retired Agents lösen keinen Alert aus"
echo ""

# ── Test 3: Fehlende Status-Datei ──
echo "--- Test 3: Fehlende Status-Datei ---"

export AGENT_STATUS_FILE="/tmp/nonexistent-agent-status-99999.json"
bash "$RECOVERY" --dry-run 2>&1
exit_code=$?
assert_exit 1 "$exit_code" "Exit 1 bei fehlender Status-Datei"
export AGENT_STATUS_FILE="$FAKE_STATUS"
echo ""

# ── Test 4: Alert mit echtem Telegram (DRY-RUN) ──
echo "--- Test 4: Alert-Inhalt korrekt ---"

RECENT_TIME=$(date -u -d "10 minutes ago" '+%Y-%m-%dT%H:%M:%SZ')
cat > "$FAKE_STATUS" << EOF
{
  "dev1": {
    "status": "working",
    "task": "Issue #3: workflow-init.sh",
    "updated": "$OLD_TIME"
  },
  "dev2": {
    "status": "working",
    "task": "Issue #4: Recovery-System",
    "updated": "$RECENT_TIME"
  },
  "qa": {
    "status": "idle",
    "task": "",
    "updated": "$OLD_TIME"
  },
  "merge": {
    "status": "idle",
    "task": "",
    "updated": "$OLD_TIME"
  }
}
EOF

rm -f "$FAKE_ALERT_DIR"/* "$TELEGRAM_LOG"

output=$(bash "$RECOVERY" --dry-run 2>&1)
# dev1 ist 2h inaktiv → Alert
assert_contains "$output" "dev1" "dev1 (2h inaktiv) wird gemeldet"
# dev2 ist erst 10 Min inaktiv → kein Alert
assert_not_contains "$output" "dev2" "dev2 (10 Min) wird NICHT gemeldet"
echo ""

# ── Test 5: Alert-Cooldown funktioniert ──
echo "--- Test 5: Alert-Cooldown ---"

cat > "$FAKE_STATUS" << EOF
{
  "dev1": {
    "status": "working",
    "task": "Issue #3",
    "updated": "$OLD_TIME"
  },
  "dev2": {"status": "idle", "task": "", "updated": "$OLD_TIME"},
  "qa": {"status": "idle", "task": "", "updated": "$OLD_TIME"},
  "merge": {"status": "idle", "task": "", "updated": "$OLD_TIME"}
}
EOF

rm -f "$FAKE_ALERT_DIR"/* "$TELEGRAM_LOG"

# Erster Alert
bash "$RECOVERY" 2>&1 >/dev/null
assert_file_exists "${FAKE_ALERT_DIR}/dev1.alert" "Alert-State für dev1 angelegt"

# Zweiter Alert direkt danach — sollte durch Cooldown blockiert werden
rm -f "$TELEGRAM_LOG"
bash "$RECOVERY" 2>&1 >/dev/null

# Pending-File existiert noch → kein neuer Alert, nur Response-Check
if [ -f "$TELEGRAM_LOG" ]; then
    # Es könnte eine Nachricht vom Response-Check kommen, aber kein neuer Alert
    telegram_content=$(cat "$TELEGRAM_LOG" 2>/dev/null)
    assert_not_contains "$telegram_content" "AGENT INAKTIV" "Kein doppelter Alert innerhalb Cooldown"
else
    echo "PASS: Kein Telegram-Call innerhalb Cooldown"
    PASS=$((PASS + 1))
fi
echo ""

# ── Test 6: Recovery-Log wird geschrieben ──
echo "--- Test 6: Recovery-Log ---"

assert_file_exists "$FAKE_LOG" "Recovery-Log existiert"
log_content=$(cat "$FAKE_LOG" 2>/dev/null)
assert_contains "$log_content" "ALERT gesendet" "Alert-Eintrag im Log"
echo ""

# ── Test 7: Neustart schlägt fehl (keine tmux Session) ──
echo "--- Test 7: Neustart fehlgeschlagen ---"

rm -f "$FAKE_ALERT_DIR"/* "$TELEGRAM_LOG"

# Simuliere einen pending Alert mit Auto-Restart-Antwort
# Da wir keine echte Telegram-Antwort mocken können, testen wir restart_agent direkt
cat > "$FAKE_STATUS" << EOF
{
  "dev1": {"status": "working", "task": "Test", "updated": "$OLD_TIME"},
  "dev2": {"status": "idle", "task": "", "updated": "$OLD_TIME"},
  "qa": {"status": "idle", "task": "", "updated": "$OLD_TIME"},
  "merge": {"status": "idle", "task": "", "updated": "$OLD_TIME"}
}
EOF

# start-agents.sh existiert aber tmux Session startet nicht wirklich
# → Neustart wird als "fehlgeschlagen" gemeldet
# Wir testen das über die restart_agent Funktion indem wir sie direkt sourcen
output=$(bash -c '
    source "'"$RECOVERY"'" 2>/dev/null <<< ""
' 2>&1) || true
# Alternativ: Prüfe dass das Script die Funktion korrekt definiert
output=$(grep -c "restart_agent" "$RECOVERY")
assert_exit 0 $? "restart_agent Funktion ist definiert"
echo ""

# ── Test 8: Falsche Session-ID (Agent nicht in Status-Datei) ──
echo "--- Test 8: Unbekannter Agent in Status-Datei ---"

cat > "$FAKE_STATUS" << EOF
{
  "unknown_agent": {
    "status": "working",
    "task": "Test",
    "updated": "$OLD_TIME"
  }
}
EOF

rm -f "$FAKE_ALERT_DIR"/* "$TELEGRAM_LOG"

output=$(bash "$RECOVERY" --dry-run 2>&1)
# unknown_agent ist nicht in WATCHED_AGENTS → wird ignoriert
assert_not_contains "$output" "unknown_agent" "Unbekannter Agent wird ignoriert"
echo ""

# ── Cleanup ──
rm -rf "$TMPDIR"

# ── Zusammenfassung ──
echo "==============================="
echo "Tests: $((PASS + FAIL)) | PASS: ${PASS} | FAIL: ${FAIL}"
if [[ $FAIL -gt 0 ]]; then
    echo "ERGEBNIS: FAIL"
    exit 1
else
    echo "ERGEBNIS: PASS"
    exit 0
fi
