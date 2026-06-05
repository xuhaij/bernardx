#!/usr/bin/env bash
# run_batch.sh — Run all scenarios for specified levels
#
# Usage:
#   ./run_batch.sh [levels...]
#   ./run_batch.sh 1          # Level 1 only
#   ./run_batch.sh 1 2        # Level 1 + 2
#   ./run_batch.sh all         # All 19 scenarios
#   ./run_batch.sh --list      # List scenarios without running
#
# Environment:
#   RETRY_COUNT   — retries per scenario (default: 1)
#   STOP_ON_FAIL  — stop batch on first failure (default: 0)
#   LOG_DIR       — log output directory

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/services.sh"

# --- Scenario registry ---
declare -a L1_SCENARIOS=(
    "l1-click-button:Fill in a name and click Submit"
    "l1-type-search:Search for a Product"
    "l1-toggle-checkbox:Enable Auto-save"
)
declare -a L2_SCENARIOS=(
    "l2-fill-from-instructions:Fill Form from Instructions"
    "l2-select-best-value:Select Best Value Product"
    "l2-answer-from-page:Extract Data from Dashboard"
    "l2-navigate-dropdown:Navigate to Headphones Category"
)
declare -a L3_SCENARIOS=(
    "l3-price-compare:Budget Laptop Comparison"
    "l3-filter-sort:Filter and Sort Products"
    "l3-conditional-action:Cancel Processing Order"
    "l3-form-validation:Generate Compliant Password"
)
declare -a L4_SCENARIOS=(
    "l4-checkout-flow:Complete Shopping Flow"
    "l4-account-setup:Account Setup Workflow"
    "l4-data-entry:Business Card Data Entry"
    "l4-file-management:File Organization"
)
declare -a L5_SCENARIOS=(
    "l5-form-errors:Fix Form Validation Errors"
    "l5-disappearing-elements:Wait and Claim Reward"
    "l5-server-errors:Retry on Server Errors"
    "l5-dynamic-price:Buy at Right Price"
)

# --- Collect scenarios to run ---
SCENARIOS=()
LIST_ONLY=0

for arg in "$@"; do
    case "$arg" in
        --list) LIST_ONLY=1 ;;
        all)    SCENARIOS+=(
                    "${L1_SCENARIOS[@]}" "${L2_SCENARIOS[@]}"
                    "${L3_SCENARIOS[@]}" "${L4_SCENARIOS[@]}"
                    "${L5_SCENARIOS[@]}"
                ) ;;
        1) SCENARIOS+=("${L1_SCENARIOS[@]}") ;;
        2) SCENARIOS+=("${L2_SCENARIOS[@]}") ;;
        3) SCENARIOS+=("${L3_SCENARIOS[@]}") ;;
        4) SCENARIOS+=("${L4_SCENARIOS[@]}") ;;
        5) SCENARIOS+=("${L5_SCENARIOS[@]}") ;;
        *) log_fail "Unknown argument: ${arg}"; exit 1 ;;
    esac
done

# Default: L1 + L2
if [[ ${#SCENARIOS[@]} -eq 0 ]]; then
    SCENARIOS+=("${L1_SCENARIOS[@]}" "${L2_SCENARIOS[@]}")
fi

# --- List mode ---
if [[ $LIST_ONLY -eq 1 ]]; then
    printf "%-30s %-6s %s\n" "SCENARIO_ID" "LEVEL" "DESCRIPTION"
    for entry in "${SCENARIOS[@]}"; do
        id="${entry%%:*}"
        desc="${entry#*:}"
        lvl="${id:1:1}"
        printf "%-30s L%-5s %s\n" "$id" "$lvl" "$desc"
    done
    exit 0
fi

# --- Prerequisites ---
RETRY_COUNT="${RETRY_COUNT:-1}"
STOP_ON_FAIL="${STOP_ON_FAIL:-0}"
LOG_DIR="${LOG_DIR:-/tmp/bernardx_e2e_$(date +%Y%m%d_%H%M%S)}"
mkdir -p "${LOG_DIR}"

log_info "=== Batch run: ${#SCENARIOS[@]} scenarios, retries=${RETRY_COUNT} ==="
log_info "Logs: ${LOG_DIR}"

check_prereqs || { log_fail "Prerequisites failed"; exit $E_PREREQ; }
reset_all

# --- Run each scenario ---
declare -a PASSED=()
declare -a FAILED=()
declare -a TIMED_OUT=()
TOTAL_START=$(date +%s)

for entry in "${SCENARIOS[@]}"; do
    scenario_id="${entry%%:*}"

    log_info "--- Running: ${scenario_id} ---"

    "${SCRIPT_DIR}/run_scenario.sh" "${scenario_id}" \
        --retry "${RETRY_COUNT}" \
        --log-dir "${LOG_DIR}" || true
    rc=$?

    case $rc in
        $E_OK)         PASSED+=("${scenario_id}") ;;
        $E_VERIFY_FAIL) FAILED+=("${scenario_id}") ;;
        $E_TIMEOUT)    TIMED_OUT+=("${scenario_id}") ;;
        *)             FAILED+=("${scenario_id}") ;;
    esac

    if [[ "${STOP_ON_FAIL}" == "1" && $rc -ne 0 ]]; then
        log_warn "Stopping batch on failure (STOP_ON_FAIL=1)"
        break
    fi

    sleep 2
done

TOTAL_ELAPSED=$(( $(date +%s) - TOTAL_START ))

# --- Summary report ---
echo ""
echo "============================================"
echo "  BATCH RESULTS"
echo "============================================"
echo "  Total:      ${#SCENARIOS[@]}"
echo "  Passed:     ${#PASSED[@]}"
echo "  Failed:     ${#FAILED[@]}"
echo "  Timed out:  ${#TIMED_OUT[@]}"
echo "  Duration:   $((TOTAL_ELAPSED / 60))m $((TOTAL_ELAPSED % 60))s"
echo "============================================"

if [[ ${#PASSED[@]} -gt 0 ]]; then
    echo "  PASSED:"
    for s in "${PASSED[@]}"; do echo "    [PASS] ${s}"; done
fi
if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo "  FAILED:"
    for s in "${FAILED[@]}"; do echo "    [FAIL] ${s}"; done
fi
if [[ ${#TIMED_OUT[@]} -gt 0 ]]; then
    echo "  TIMED OUT:"
    for s in "${TIMED_OUT[@]}"; do echo "    [TIME] ${s}"; done
fi
echo "============================================"
echo "  Log directory: ${LOG_DIR}"
echo "============================================"

# --- Write machine-readable results ---
RESULTS_FILE="${LOG_DIR}/results.json"
{
    echo "{"
    echo "  \"timestamp\": \"$(date -Iseconds)\","
    echo "  \"total\": ${#SCENARIOS[@]},"
    echo "  \"passed\": ${#PASSED[@]},"
    echo "  \"failed\": ${#FAILED[@]},"
    echo "  \"timed_out\": ${#TIMED_OUT[@]},"
    echo "  \"duration_secs\": ${TOTAL_ELAPSED},"
    echo "  \"results\": ["
    first=1
    for s in "${PASSED[@]}"; do
        [[ $first -eq 0 ]] && echo ","
        echo -n "    {\"id\": \"${s}\", \"status\": \"passed\"}"
        first=0
    done
    for s in "${FAILED[@]}"; do
        [[ $first -eq 0 ]] && echo ","
        echo -n "    {\"id\": \"${s}\", \"status\": \"failed\"}"
        first=0
    done
    for s in "${TIMED_OUT[@]}"; do
        [[ $first -eq 0 ]] && echo ","
        echo -n "    {\"id\": \"${s}\", \"status\": \"timeout\"}"
        first=0
    done
    echo ""
    echo "  ]"
    echo "}"
} > "${RESULTS_FILE}"

log_info "Results written to ${RESULTS_FILE}"

[[ ${#FAILED[@]} -eq 0 && ${#TIMED_OUT[@]} -eq 0 ]]
