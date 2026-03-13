#!/usr/bin/env bash
# Tests für workflow-doctor.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCTOR="${SCRIPT_DIR}/scripts/workflow-doctor.sh"
PASS=0
FAIL=0

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
        echo "FAIL: ${test_name} (pattern '${pattern}' not found in output)"
        FAIL=$((FAIL + 1))
    fi
}

assert_json_valid() {
    local output="$1"
    local test_name="$2"
    if echo "$output" | python3 -m json.tool &>/dev/null; then
        echo "PASS: ${test_name}"
        PASS=$((PASS + 1))
    else
        echo "FAIL: ${test_name} (invalid JSON)"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== Test Suite: workflow-doctor.sh ==="
echo ""

# --- Test 1: Happy Path (Default-Report) ---
echo "--- Test 1: Happy Path (Report-Format) ---"
output=$(bash "$DOCTOR" 2>&1) || true
exit_code=$?

assert_contains "$output" "=== Workflow Doctor Report ===" "Report-Header vorhanden"
assert_contains "$output" "Ergebnis:" "Ergebnis-Zeile vorhanden"
assert_contains "$output" "Claude API" "Claude API Check vorhanden"
assert_contains "$output" "GitHub Token" "GitHub Token Check vorhanden"
echo ""

# --- Test 2: JSON-Output ---
echo "--- Test 2: JSON Output ---"
json_output=$(bash "$DOCTOR" --json 2>&1) || true
assert_json_valid "$json_output" "JSON Output ist valides JSON"
assert_contains "$json_output" '"total":' "JSON enthält total"
assert_contains "$json_output" '"ok":' "JSON enthält ok"
assert_contains "$json_output" '"fail":' "JSON enthält fail"
assert_contains "$json_output" '"checks":' "JSON enthält checks"
echo ""

# --- Test 3: Quiet-Mode ---
echo "--- Test 3: Quiet Mode ---"
quiet_output=$(bash "$DOCTOR" --quiet 2>&1) || true
# Im quiet mode sollten OK-Einträge NICHT erscheinen (falls es welche gibt)
# Wir prüfen nur dass der Report-Header da ist
assert_contains "$quiet_output" "=== Workflow Doctor Report ===" "Quiet-Mode hat Report-Header"
assert_contains "$quiet_output" "Ergebnis:" "Quiet-Mode hat Ergebnis"
echo ""

# --- Test 4: Fehlende tmux Session erkennen ---
echo "--- Test 4: Fehlende tmux Session ---"
# Erstelle temporäre Session, dann prüfe ob eine nicht-existierende erkannt wird
output=$(bash "$DOCTOR" 2>&1) || true
# dev2 läuft wahrscheinlich nicht im Test-Kontext
if ! tmux has-session -t "dev2" 2>/dev/null; then
    assert_contains "$output" "[FAIL] tmux: dev2 fehlt!" "Fehlende tmux Session erkannt"
else
    echo "SKIP: dev2 Session läuft, kann FAIL nicht testen"
fi
echo ""

# --- Test 5: agent-status.json alt/fehlt ---
echo "--- Test 5: agent-status.json veraltet ---"
# Temporäre alte Datei erstellen
TMPDIR=$(mktemp -d)
FAKE_STATUS="${TMPDIR}/agent-status.json"
echo '{"test":true}' > "$FAKE_STATUS"
# Setze Modifikationszeit auf 3 Stunden her (> 120 Min Limit)
touch -d "3 hours ago" "$FAKE_STATUS"

# Überschreibe die Konfigurationsvariable für den Test
output=$(AGENT_STATUS_FILE="$FAKE_STATUS" bash -c '
    # Source des Scripts mit überschriebenem Pfad
    export AGENT_STATUS_FILE="'"$FAKE_STATUS"'"
    sed "s|AGENT_STATUS_FILE=.*|AGENT_STATUS_FILE=\"'"$FAKE_STATUS"'\"|" "'"$DOCTOR"'" | bash
' 2>&1) || true
assert_contains "$output" "[FAIL]" "Veraltete agent-status.json wird als FAIL erkannt"
rm -rf "$TMPDIR"
echo ""

# --- Test 6: agent-status.json fehlt komplett ---
echo "--- Test 6: agent-status.json fehlt ---"
output=$(sed 's|AGENT_STATUS_FILE=.*|AGENT_STATUS_FILE="/tmp/nonexistent-status-12345.json"|' "$DOCTOR" | bash 2>&1) || true
assert_contains "$output" "agent-status.json fehlt" "Fehlende agent-status.json erkannt"
echo ""

# --- Test 7: API nicht erreichbar (Mock) ---
echo "--- Test 7: API nicht erreichbar ---"
output=$(CLAUDE_API_URL="https://localhost:19999" bash "$DOCTOR" 2>&1) || true
assert_contains "$output" "[FAIL] Claude API nicht erreichbar" "Nicht erreichbare API erkannt"
echo ""

# --- Test 8: Exit-Code bei Failures ---
echo "--- Test 8: Exit-Code ---"
# Mit ungültiger API-URL sollte mindestens ein FAIL da sein → Exit 1
CLAUDE_API_URL="https://localhost:19999" bash "$DOCTOR" &>/dev/null
exit_code=$?
assert_exit 1 "$exit_code" "Exit-Code 1 bei FAIL"
echo ""

# --- Zusammenfassung ---
echo "==============================="
echo "Tests: $((PASS + FAIL)) | PASS: ${PASS} | FAIL: ${FAIL}"
if [[ $FAIL -gt 0 ]]; then
    echo "ERGEBNIS: FAIL"
    exit 1
else
    echo "ERGEBNIS: PASS"
    exit 0
fi
