#!/usr/bin/env bash
# run_scenario.sh — Run a single scenario end-to-end
#
# Usage:
#   ./run_scenario.sh <scenario_id> [timeout_secs] [--retry <N>] [--log-dir <path>]
#
# Examples:
#   ./run_scenario.sh l1-click-button
#   ./run_scenario.sh l2-fill-from-instructions 240 --retry 1
#   ./run_scenario.sh l1-type-search 120 --log-dir /tmp/e2e-logs

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/services.sh"

# --- Argument parsing ---
SCENARIO_ID="${1:?Usage: $0 <scenario_id> [timeout] [--retry N] [--log-dir PATH]}"
shift

TIMEOUT_SECS=""
RETRIES=0
LOG_DIR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --retry)   RETRIES="${2:?--retry needs N}"; shift 2 ;;
        --log-dir) LOG_DIR="${2:?--log-dir needs PATH}"; shift 2 ;;
        *)         TIMEOUT_SECS="$1"; shift ;;
    esac
done

TREE_DIR=$(scenario_to_tree_dir "${SCENARIO_ID}")
SCENARIO_LEVEL="${SCENARIO_ID:1:1}"

if [[ -z "${TIMEOUT_SECS}" ]]; then
    TIMEOUT_SECS=$(level_timeout "${SCENARIO_LEVEL}")
fi

if [[ -n "${LOG_DIR}" ]]; then
    mkdir -p "${LOG_DIR}"
    LOG_FILE="${LOG_DIR}/${SCENARIO_ID}.log"
else
    LOG_FILE="/tmp/bernardx_test_${SCENARIO_ID}.log"
fi

# --- Validate env vars ---
for var in ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL ANTHROPIC_DEFAULT_SONNET_MODEL; do
    if [[ -z "${!var:-}" ]]; then
        log_fail "Missing env var: ${var}"
        exit $E_MISCONFIG
    fi
done

# --- Prerequisites ---
log_info "=== Scenario: ${SCENARIO_ID} (level ${SCENARIO_LEVEL}, timeout ${TIMEOUT_SECS}s) ==="
check_prereqs || exit $E_PREREQ

if [[ ! -d "${PROJECT_PATH}/trees/${TREE_DIR}" ]]; then
    log_fail "Tree directory not found: ${PROJECT_PATH}/trees/${TREE_DIR}"
    exit $E_MISCONFIG
fi

# --- Execute with retry loop ---
attempt=0
max_attempts=$((RETRIES + 1))

while [[ $attempt -lt $max_attempts ]]; do
    attempt=$((attempt + 1))

    if [[ $attempt -gt 1 ]]; then
        log_warn "Retry attempt ${attempt}/${max_attempts}"
        sleep 2
    fi

    reset_scenario "${SCENARIO_ID}" || exit $E_PREREQ

    start_timer
    log_info "Starting agent (attempt ${attempt})..."

    run_agent_run_mode "${SCENARIO_ID}" "${TREE_DIR}" "${TIMEOUT_SECS}" "${LOG_FILE}"
    agent_rc=$?

    elapsed=$(elapsed_fmt)

    if [[ $agent_rc -eq 124 ]]; then
        log_fail "TIMEOUT after ${elapsed} — ${SCENARIO_ID}"
        if [[ $attempt -lt $max_attempts ]]; then continue; fi
        exit $E_TIMEOUT
    elif [[ $agent_rc -ne 0 ]]; then
        log_fail "Agent crashed (exit ${agent_rc}) after ${elapsed} — ${SCENARIO_ID}"
        if [[ $attempt -lt $max_attempts ]]; then continue; fi
        exit $E_AGENT_CRASH
    fi

    log_info "Agent completed in ${elapsed}"

    verify_resp=$(verify_scenario "${SCENARIO_ID}")
    verify_rc=$?

    if [[ $verify_rc -eq 0 ]]; then
        log_pass "PASSED: ${SCENARIO_ID} (${elapsed})"
        exit $E_OK
    else
        msg=$(echo "$verify_resp" | grep -o '"message":"[^"]*"' | head -1)
        log_fail "VERIFY FAILED: ${SCENARIO_ID} — ${msg}"
        if [[ $attempt -lt $max_attempts ]]; then continue; fi
        exit $E_VERIFY_FAIL
    fi
done

exit $E_VERIFY_FAIL
