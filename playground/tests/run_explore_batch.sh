#!/usr/bin/env bash
# run_explore_batch.sh — Run explore mode for multiple scenarios
#
# Usage:
#   ./run_explore_batch.sh [levels...]
#   ./run_explore_batch.sh 1
#   ./run_explore_batch.sh 1 2
#   ./run_explore_batch.sh all
#
# Each scenario's description (from registry) is used as the TASK.
# Environment:
#   STOP_ON_FAIL  — stop batch on first failure (default: 0)
#   LOG_DIR       — log output directory

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/services.sh"

# --- Scenario registry (same as run_batch.sh) ---
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

# --- Collect scenarios ---
SCENARIOS=()

for arg in "$@"; do
    case "$arg" in
        all) SCENARIOS+=(
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

if [[ ${#SCENARIOS[@]} -eq 0 ]]; then
    SCENARIOS+=("${L1_SCENARIOS[@]}" "${L2_SCENARIOS[@]}")
fi

# --- Prerequisites ---
STOP_ON_FAIL="${STOP_ON_FAIL:-0}"
LOG_DIR="${LOG_DIR:-/tmp/bernardx_explore_e2e_$(date +%Y%m%d_%H%M%S)}"
mkdir -p "${LOG_DIR}"

log_info "=== Explore batch: ${#SCENARIOS[@]} scenarios ==="
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
    task="${entry#*:}"

    log_info "--- Exploring: ${scenario_id} — ${task} ---"

    "${SCRIPT_DIR}/run_explore.sh" "${scenario_id}" "${task}" \
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
echo "  EXPLORE BATCH RESULTS"
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

[[ ${#FAILED[@]} -eq 0 && ${#TIMED_OUT[@]} -eq 0 ]]
