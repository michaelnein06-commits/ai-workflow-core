#!/usr/bin/env bash
# Workflow Doctor — Health Checks für die AI-Workflow Infrastruktur
# Cron: 0 8 * * * /root/projects/ai-workflow-core/scripts/workflow-doctor.sh --json | /root/scripts/notify-telegram.sh
set -uo pipefail

# --- Konfiguration ---
AGENT_STATUS_FILE="/root/share/05-system/agent-status.json"
AGENT_STATUS_MAX_AGE_MIN=120  # 2 Stunden
TMUX_SESSIONS=(orchestrator dev1 dev2 qa merge)
START_AGENTS_SCRIPT="/home/micha/start-agents.sh"
GCLI_CMD="/root/projects/google-cli/scripts/gary-gcli.sh"

# --- Variablen ---
TOTAL=0
OK_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
FIX_MODE=false
JSON_MODE=false
QUIET_MODE=false
RESULTS=()

# --- Flags parsen ---
for arg in "$@"; do
    case "$arg" in
        --fix)   FIX_MODE=true ;;
        --json)  JSON_MODE=true ;;
        --quiet) QUIET_MODE=true ;;
    esac
done

# --- Hilfsfunktionen ---
record_result() {
    local status="$1"  # OK, FAIL, SKIP
    local name="$2"
    local detail="${3:-}"

    TOTAL=$((TOTAL + 1))
    case "$status" in
        OK)   OK_COUNT=$((OK_COUNT + 1)) ;;
        FAIL) FAIL_COUNT=$((FAIL_COUNT + 1)) ;;
        SKIP) SKIP_COUNT=$((SKIP_COUNT + 1)) ;;
    esac

    RESULTS+=("${status}|${name}|${detail}")
}

print_report() {
    if $JSON_MODE; then
        print_json
        return
    fi

    echo "=== Workflow Doctor Report ==="
    for entry in "${RESULTS[@]}"; do
        local status="${entry%%|*}"
        local rest="${entry#*|}"
        local name="${rest%%|*}"
        local detail="${rest#*|}"

        if $QUIET_MODE && [[ "$status" == "OK" ]]; then
            continue
        fi

        local label
        case "$status" in
            OK)   label="[OK]  " ;;
            FAIL) label="[FAIL]" ;;
            SKIP) label="[SKIP]" ;;
        esac

        if [[ -n "$detail" ]]; then
            echo "$label $name ($detail)"
        else
            echo "$label $name"
        fi
    done
    echo "============================="
    echo "Ergebnis: ${OK_COUNT}/${TOTAL} OK, ${FAIL_COUNT} FAIL, ${SKIP_COUNT} SKIP"
}

print_json() {
    local checks_json="["
    local first=true
    for entry in "${RESULTS[@]}"; do
        local status="${entry%%|*}"
        local rest="${entry#*|}"
        local name="${rest%%|*}"
        local detail="${rest#*|}"

        if ! $first; then checks_json+=","; fi
        first=false
        checks_json+="{\"status\":\"${status}\",\"name\":\"${name}\",\"detail\":\"${detail}\"}"
    done
    checks_json+="]"

    cat <<ENDJSON
{"total":${TOTAL},"ok":${OK_COUNT},"fail":${FAIL_COUNT},"skip":${SKIP_COUNT},"checks":${checks_json}}
ENDJSON
}

# --- Check 1: Claude API erreichbar ---
check_claude_api() {
    local url="${CLAUDE_API_URL:-https://api.anthropic.com}"
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "$url" 2>/dev/null) || true

    if [[ "$http_code" =~ ^[2345] ]]; then
        record_result "OK" "Claude API erreichbar"
    else
        record_result "FAIL" "Claude API nicht erreichbar" "HTTP ${http_code}"
    fi
}

# --- Check 2: tmux Sessions ---
check_tmux_sessions() {
    local missing_sessions=()

    for session in "${TMUX_SESSIONS[@]}"; do
        if tmux has-session -t "$session" 2>/dev/null; then
            record_result "OK" "tmux: ${session} läuft"
        else
            record_result "FAIL" "tmux: ${session} fehlt!"
            missing_sessions+=("$session")
        fi
    done

    # --fix: fehlende Sessions neu starten
    if $FIX_MODE && [[ ${#missing_sessions[@]} -gt 0 ]]; then
        if [[ -x "$START_AGENTS_SCRIPT" ]]; then
            echo "[FIX] Starte fehlende Sessions mit ${START_AGENTS_SCRIPT}..."
            bash "$START_AGENTS_SCRIPT" 2>/dev/null || true
        fi
    fi
}

# --- Check 3: agent-status.json aktuell ---
check_agent_status() {
    if [[ ! -f "$AGENT_STATUS_FILE" ]]; then
        record_result "FAIL" "agent-status.json fehlt"
        return
    fi

    local now file_mod file_age_sec file_age_min
    now=$(date +%s)
    file_mod=$(stat -c %Y "$AGENT_STATUS_FILE" 2>/dev/null || stat -f %m "$AGENT_STATUS_FILE" 2>/dev/null) || {
        record_result "FAIL" "agent-status.json nicht lesbar"
        return
    }

    file_age_sec=$((now - file_mod))
    file_age_min=$((file_age_sec / 60))

    if [[ $file_age_min -lt $AGENT_STATUS_MAX_AGE_MIN ]]; then
        record_result "OK" "agent-status.json aktuell" "vor ${file_age_min} Min"
    else
        record_result "FAIL" "agent-status.json veraltet" "vor ${file_age_min} Min, max ${AGENT_STATUS_MAX_AGE_MIN} Min"
    fi
}

# --- Check 4: GitHub Token gültig ---
check_github_token() {
    if gh auth status &>/dev/null; then
        record_result "OK" "GitHub Token gültig"
    else
        record_result "FAIL" "GitHub Token ungültig oder abgelaufen"
    fi
}

# --- Check 5: Google OAuth Token ---
check_google_oauth() {
    if [[ ! -x "$GCLI_CMD" ]] && [[ ! -f "$GCLI_CMD" ]]; then
        record_result "SKIP" "Google OAuth" "gcli nicht gefunden"
        return
    fi

    if bash "$GCLI_CMD" mail list --limit 1 --json &>/dev/null; then
        record_result "OK" "Google OAuth Token gültig"
    else
        record_result "FAIL" "Google OAuth Token ungültig"
    fi
}

# --- Alle Checks ausführen ---
check_claude_api
check_tmux_sessions
check_agent_status
check_github_token
check_google_oauth

# --- Report ausgeben ---
print_report

# --- Exit Code ---
if [[ $FAIL_COUNT -gt 0 ]]; then
    exit 1
fi
exit 0
