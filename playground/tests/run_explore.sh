#!/usr/bin/env bash
# run_explore.sh — Test explore mode for a single scenario
#
# Usage:
#   ./run_explore.sh <scenario_id> "<task_description>" [timeout_secs] [--log-dir <path>]
#
# Examples:
#   ./run_explore.sh l1-click-button "Click the Submit button" 120
#   ./run_explore.sh l2-answer-from-page "What is the temperature in Tokyo?" 180

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/services.sh"

SCENARIO_ID="${1:?Usage: $0 <scenario_id> <task> [timeout] [--log-dir PATH]}"
TASK="${2:?Task description required}"
shift 2

TIMEOUT_SECS=""
LOG_DIR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --log-dir) LOG_DIR="${2}"; shift 2 ;;
        *)         TIMEOUT_SECS="$1"; shift ;;
    esac
done

SCENARIO_LEVEL="${SCENARIO_ID:1:1}"
TIMEOUT_SECS="${TIMEOUT_SECS:-$(level_timeout "${SCENARIO_LEVEL}")}"

if [[ -n "${LOG_DIR}" ]]; then
    mkdir -p "${LOG_DIR}"
    LOG_FILE="${LOG_DIR}/explore_${SCENARIO_ID}.log"
else
    LOG_FILE="/tmp/bernardx_explore_${SCENARIO_ID}.log"
fi

log_info "=== Explore: ${SCENARIO_ID} | task='${TASK}' | timeout=${TIMEOUT_SECS}s ==="
check_prereqs || exit $E_PREREQ
reset_scenario "${SCENARIO_ID}" || exit $E_PREREQ

start_timer
run_agent_explore_mode "${SCENARIO_ID}" "${TASK}" "${TIMEOUT_SECS}" "${LOG_FILE}"
agent_rc=$?

elapsed=$(elapsed_fmt)

if [[ $agent_rc -eq 124 ]]; then
    log_fail "EXPLORE TIMEOUT: ${SCENARIO_ID} (${elapsed})"
    exit $E_TIMEOUT
elif [[ $agent_rc -ne 0 ]]; then
    log_fail "EXPLORE CRASH: ${SCENARIO_ID} exit=${agent_rc} (${elapsed})"
    exit $E_AGENT_CRASH
fi

verify_resp=$(verify_scenario "${SCENARIO_ID}")
verify_rc=$?

if [[ $verify_rc -eq 0 ]]; then
    log_pass "EXPLORE PASSED: ${SCENARIO_ID} (${elapsed})"
    exit $E_OK
else
    msg=$(echo "$verify_resp" | grep -o '"message":"[^"]*"' | head -1)
    log_fail "EXPLORE VERIFY FAILED: ${SCENARIO_ID} — ${msg} (${elapsed})"
    exit $E_VERIFY_FAIL
fi
