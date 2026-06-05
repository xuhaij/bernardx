#!/usr/bin/env bash
# Service interaction functions for bernardx e2e tests
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# --- Configuration with defaults ---
PLAYGROUND_URL="${PLAYGROUND_URL:-http://localhost:3000}"
CDP_PORT="${CDP_PORT:-9222}"
BERNARDX_BIN="${BERNARDX_BIN:-/workspaces/example/bernardx/build/bernardx}"
PROJECT_PATH="${PROJECT_PATH:-/workspaces/example/playground/bt_project}"
AGENT_DIR="${AGENT_DIR:-/workspaces/example/bernardx-agent}"

# --- Timeout defaults per level (seconds) ---
DEFAULT_TIMEOUT=180

level_timeout() {
    local level="$1"
    case "$level" in
        1) echo 120 ;;
        2) echo 180 ;;
        3) echo 240 ;;
        4) echo 300 ;;
        5) echo 360 ;;
        *) echo "$DEFAULT_TIMEOUT" ;;
    esac
}

# --- Health checks ---

check_playground() {
    local url="${PLAYGROUND_URL}/api/scenarios"
    local attempts=10
    for ((i = 1; i <= attempts; i++)); do
        if curl -sf --max-time 2 "$url" > /dev/null 2>&1; then
            log_info "Playground ready at ${PLAYGROUND_URL}"
            return 0
        fi
        sleep 1
    done
    log_fail "Playground not responding at ${PLAYGROUND_URL} after ${attempts}s"
    return 1
}

check_chrome() {
    local url="http://localhost:${CDP_PORT}/json/version"
    local attempts=10
    for ((i = 1; i <= attempts; i++)); do
        if curl -sf --max-time 2 "$url" > /dev/null 2>&1; then
            log_info "Chrome CDP ready on port ${CDP_PORT}"
            return 0
        fi
        sleep 1
    done
    log_fail "Chrome CDP not responding on port ${CDP_PORT} after ${attempts}s"
    return 1
}

check_prereqs() {
    if [[ ! -x "${BERNARDX_BIN}" ]]; then
        log_fail "bernardx binary not found at ${BERNARDX_BIN}"
        return 1
    fi
    check_playground || return 1
    check_chrome    || return 1
}

# --- Scenario state management ---

reset_scenario() {
    local scenario_id="$1"
    local resp
    resp=$(curl -sf -X POST "${PLAYGROUND_URL}/api/admin/reset/${scenario_id}" 2>&1)
    if [[ $? -ne 0 ]]; then
        log_fail "Failed to reset scenario ${scenario_id}: ${resp}"
        return 1
    fi
    log_info "Reset scenario: ${scenario_id}"
}

reset_all() {
    curl -sf -X POST "${PLAYGROUND_URL}/api/admin/reset" > /dev/null 2>&1
}

# --- Verification ---

verify_scenario() {
    local scenario_id="$1"
    local resp
    resp=$(curl -sf --max-time 5 "${PLAYGROUND_URL}/verify/${scenario_id}" 2>&1)
    local rc=$?
    if [[ $rc -ne 0 ]]; then
        echo "{\"passed\":false,\"message\":\"verify request failed: ${resp}\"}"
        return 1
    fi
    echo "$resp"
    local passed
    passed=$(echo "$resp" | grep -o '"passed":[[:space:]]*true')
    [[ -n "$passed" ]]
}

# --- ID mapping ---

scenario_to_tree_dir() {
    echo "${1//-/_}"
}

# --- Agent execution ---

run_agent_run_mode() {
    local scenario_id="$1"
    local tree_dir="$2"
    local timeout_secs="$3"
    local log_file="${4:-/dev/stderr}"

    export MODE="run"
    export SCENARIO_ID="${scenario_id}"
    export TREE_DIR="${tree_dir}"
    export PROJECT_PATH="${PROJECT_PATH}"
    export PLAYGROUND_URL="${PLAYGROUND_URL}"
    export CDP_PORT="${CDP_PORT}"

    log_info "Running agent: scenario=${scenario_id} tree=${tree_dir} timeout=${timeout_secs}s"

    timeout "${timeout_secs}" "${BERNARDX_BIN}" --dir="${AGENT_DIR}" >> "${log_file}" 2>&1
    return $?
}

run_agent_explore_mode() {
    local scenario_id="$1"
    local task="$2"
    local timeout_secs="$3"
    local log_file="${4:-/dev/stderr}"

    export MODE="explore"
    export TARGET_URL="${PLAYGROUND_URL}/scenarios/${scenario_id}"
    export TASK="${task}"
    export OUTPUT_DIR="/tmp/bt_explore_${scenario_id}"
    export CDP_PORT="${CDP_PORT}"

    log_info "Running explore: scenario=${scenario_id} task='${task}' timeout=${timeout_secs}s"

    timeout "${timeout_secs}" "${BERNARDX_BIN}" --dir="${AGENT_DIR}" >> "${log_file}" 2>&1
    return $?
}
