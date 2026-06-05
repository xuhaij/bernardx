#!/usr/bin/env bash
# Common utilities for bernardx e2e tests

# Guard against double-sourcing
[[ -n "${_COMMON_SH_LOADED:-}" ]] && return 0
_COMMON_SH_LOADED=1

# --- Exit codes ---
readonly E_OK=0
readonly E_VERIFY_FAIL=1
readonly E_TIMEOUT=2
readonly E_PREREQ=3
readonly E_AGENT_CRASH=4
readonly E_MISCONFIG=5

# --- Logging ---
LOG_LEVEL="${LOG_LEVEL:-INFO}"

log() {
    local level="$1"; shift
    local ts
    ts=$(date '+%H:%M:%S')
    local color=""
    case "$level" in
        INFO)  color="\033[0;36m" ;;
        PASS)  color="\033[0;32m" ;;
        FAIL)  color="\033[0;31m" ;;
        WARN)  color="\033[0;33m" ;;
        *)     color="" ;;
    esac
    if [[ "${NO_COLOR:-}" == "1" ]]; then color=""; fi
    printf "${color}[%s] [%s] %s\033[0m\n" "$ts" "$level" "$*"
}

log_info()  { log "INFO" "$@"; }
log_pass()  { log "PASS" "$@"; }
log_fail()  { log "FAIL" "$@"; }
log_warn()  { log "WARN" "$@"; }

# --- Timing ---
_START_TIME=0

start_timer() { _START_TIME=$(date +%s); }

elapsed_secs() {
    echo $(( $(date +%s) - _START_TIME ))
}

elapsed_fmt() {
    local s
    s=$(elapsed_secs)
    printf "%d:%02d" $((s / 60)) $((s % 60))
}
