#!/bin/bash
# Copyright (c) 2025-2026 Marc Allgeier (fidpa)
# SPDX-License-Identifier: MIT
# https://github.com/fidpa/linux-monitoring-templates
#
# Generic Monitoring Script Template - Bash Version
#
# Production-ready template for creating monitoring scripts with:
# - Smart alerting with rate-limiting
# - State-based change detection
# - Prometheus metrics export
# - Lock-file management (prevents parallel execution)
# - Configurable recovery alerts
#
# Usage:
#   1. Copy this template to your monitoring directory
#   2. Customize SERVICE_NAME, DEVICE_NAME, and check logic
#   3. Deploy with systemd service + timer
#
# Documentation: https://github.com/fidpa/linux-monitoring-templates/blob/main/docs/SETUP.md
# Created: 2026-01-03

set -uo pipefail

# ============================================================================
# Configuration
# ============================================================================

# Service configuration (customize these)
readonly SERVICE_NAME="${SERVICE_NAME:-generic-monitor}"
readonly DEVICE_NAME="${DEVICE_NAME:-$(hostname -s)}"

# Paths (customize for your environment)
readonly STATE_DIR="${STATE_DIR:-/var/lib/${SERVICE_NAME}}"
readonly LOCK_DIR="${LOCK_DIR:-/run}"
readonly LOG_DIR="${LOG_DIR:-/var/log}"
readonly METRICS_DIR="${METRICS_DIR:-/var/lib/node_exporter/textfile_collector}"

# Derived paths
readonly LOCK_FILE="${LOCK_DIR}/${SERVICE_NAME}.lock"
readonly LOG_FILE="${LOG_DIR}/${SERVICE_NAME}.log"
readonly STATE_FILE="${STATE_DIR}/current_state"
readonly METRICS_FILE="${METRICS_DIR}/${SERVICE_NAME}.prom"

# Alert configuration
readonly TELEGRAM_PREFIX="[${DEVICE_NAME^^}] ${SERVICE_NAME}"
readonly RATE_LIMIT_SECONDS="${RATE_LIMIT_SECONDS:-10800}"  # 3 hours default
readonly ENABLE_RECOVERY_ALERTS="${ENABLE_RECOVERY_ALERTS:-true}"

# Create required directories
mkdir -p "$STATE_DIR" "$LOG_DIR" "$(dirname "$LOCK_FILE")"

# ============================================================================
# Logging Functions
# ============================================================================

log_message() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE" >&2
}

log_info() { log_message "INFO" "$@"; }
log_warn() { log_message "WARNING" "$@"; }
log_error() { log_message "ERROR" "$@"; }

# ============================================================================
# Lock Management
# ============================================================================

acquire_lock() {
    # Distinguish "cannot create the lock file" from "lock is held". Without
    # this, an unwritable LOCK_DIR (the default /run needs root) is reported as
    # "another instance is running" and sends you looking for a process that
    # does not exist.
    if ! exec 200>"$LOCK_FILE"; then
        log_error "Cannot create lock file: ${LOCK_FILE} (set LOCK_DIR to a writable path)"
        exit 1
    fi
    if ! flock -n 200; then
        log_warn "Another instance is running (lock held)"
        exit 1
    fi
}

# ============================================================================
# State Management
# ============================================================================

state_load() {
    if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE"
    else
        echo ""
    fi
}

state_save() {
    local state="$1"
    echo "$state" > "$STATE_FILE"
}

state_compare() {
    local current="$1"
    local previous="$2"

    # Split comma-separated states
    IFS=',' read -ra current_arr <<< "$current"
    IFS=',' read -ra previous_arr <<< "$previous"

    local new_issues=""
    local recovered_issues=""
    local unchanged_issues=""

    # Find new issues
    for issue in "${current_arr[@]}"; do
        [[ -z "$issue" ]] && continue
        # shellcheck disable=SC2076  # Intentional literal string match
        if [[ ! " ${previous_arr[*]} " =~ " ${issue} " ]]; then
            new_issues="${new_issues}${issue},"
        else
            unchanged_issues="${unchanged_issues}${issue},"
        fi
    done

    # Find recovered issues
    for issue in "${previous_arr[@]}"; do
        [[ -z "$issue" ]] && continue
        # shellcheck disable=SC2076  # Intentional literal string match
        if [[ ! " ${current_arr[*]} " =~ " ${issue} " ]]; then
            recovered_issues="${recovered_issues}${issue},"
        fi
    done

    # Remove trailing commas
    new_issues="${new_issues%,}"
    recovered_issues="${recovered_issues%,}"
    unchanged_issues="${unchanged_issues%,}"

    echo "${new_issues}|${recovered_issues}|${unchanged_issues}"
}

# ============================================================================
# Alert Functions
# ============================================================================

should_send_alert() {
    local alert_type="$1"
    local alert_file="${STATE_DIR}/last_alert_${alert_type}"
    local current_time
    current_time=$(date +%s)

    if [[ -f "$alert_file" ]]; then
        local last_alert
        last_alert=$(cat "$alert_file")
        local time_diff=$((current_time - last_alert))

        if (( time_diff < RATE_LIMIT_SECONDS )); then
            local remaining=$((RATE_LIMIT_SECONDS - time_diff))
            log_info "Rate limited: ${alert_type} alert skipped (${time_diff}s ago, ${remaining}s remaining)"
            return 1
        fi
    fi

    return 0
}

record_alert() {
    local alert_type="$1"
    local alert_file="${STATE_DIR}/last_alert_${alert_type}"
    date +%s > "$alert_file"
}

send_telegram_alert() {
    local message="$1"
    local emoji="${2:-⚠️}"

    # Check for Telegram credentials (customize path to your secrets file)
    local secrets_file="${SECRETS_FILE:-$HOME/.env.secrets}"
    if [[ ! -f "$secrets_file" ]]; then
        log_warn "Telegram secrets file not found: ${secrets_file}"
        return 1
    fi

    # shellcheck source=/dev/null  # Dynamic path, user-configurable
    source "$secrets_file"

    if [[ -z "${TELEGRAM_BOT_TOKEN:-}" ]] || [[ -z "${TELEGRAM_CHAT_ID:-}" ]]; then
        log_warn "Telegram credentials not configured"
        return 1
    fi

    local full_message="${emoji} ${TELEGRAM_PREFIX}\n\n${message}"

    if curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=${full_message}" \
        -d "parse_mode=Markdown" \
        --max-time 10 >/dev/null 2>&1; then
        log_info "Telegram alert sent: ${message:0:50}..."
        return 0
    else
        log_error "Failed to send Telegram alert"
        return 1
    fi
}

send_smart_alert() {
    local new_issues="$1"
    local recovered_issues="$2"
    local unchanged_issues="$3"

    # Send new issues alert
    if [[ -n "$new_issues" ]] && should_send_alert "NEW"; then
        local message=$'*New Issues Detected*\n\n'"${new_issues//,/$'\n'- }"
        if send_telegram_alert "$message" "🔴"; then
            record_alert "NEW"
        fi
    fi

    # Send recovery alert (if enabled)
    if [[ "$ENABLE_RECOVERY_ALERTS" == "true" ]] && [[ -n "$recovered_issues" ]] && should_send_alert "RECOVERY"; then
        local message=$'*Issues Resolved*\n\n'"${recovered_issues//,/$'\n'- }"
        if send_telegram_alert "$message" "✅"; then
            record_alert "RECOVERY"
        fi
    fi
}

# ============================================================================
# Monitoring Logic (CUSTOMIZE THIS)
# ============================================================================

check_system() {
    local issues=""

    # Example 1: Check service status
    if ! systemctl is-active sshd >/dev/null 2>&1; then
        issues="${issues}sshd-down,"
    fi

    # Example 2: Check disk usage
    local disk_usage
    disk_usage=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
    if (( disk_usage > 90 )); then
        issues="${issues}disk-full,"
    fi

    # Example 3: Check network connectivity
    if ! ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
        issues="${issues}network-down,"
    fi

    # Remove trailing comma
    issues="${issues%,}"

    echo "$issues"
}

# ============================================================================
# Prometheus Metrics Export
# ============================================================================

export_metrics() {
    local status="$1"  # 0=OK, 1=WARNING, 2=CRITICAL

    # Prometheus export is opt-in: the textfile collector directory is created
    # by the node_exporter setup, not by this script. No directory, no export.
    [[ ! -d "$METRICS_DIR" ]] && return 0

    # Atomic write: build the file beside its target, then rename it into place.
    # A direct write can be scraped half-finished; POSIX rename() cannot.
    local temp_file="${METRICS_FILE}.$$"

    cat > "$temp_file" <<EOF
# HELP ${SERVICE_NAME}_status Monitoring status (0=OK, 1=WARNING, 2=CRITICAL)
# TYPE ${SERVICE_NAME}_status gauge
${SERVICE_NAME}_status ${status}

# HELP ${SERVICE_NAME}_last_check_timestamp Last check timestamp (Unix time)
# TYPE ${SERVICE_NAME}_last_check_timestamp gauge
${SERVICE_NAME}_last_check_timestamp $(date +%s)
EOF

    chmod 644 "$temp_file"
    mv -f "$temp_file" "$METRICS_FILE"

    log_info "Prometheus metrics exported to ${METRICS_FILE}"
}

# ============================================================================
# Main Function
# ============================================================================

main() {
    log_info "Starting ${SERVICE_NAME} monitoring check"

    # Acquire lock (prevents parallel execution)
    acquire_lock

    # Check current system state
    local current_issues
    if ! current_issues=$(check_system); then
        log_error "System check failed"
        export_metrics 2
        return 1
    fi

    # Load previous state
    local previous_issues
    previous_issues=$(state_load)

    # Compare states
    local comparison
    comparison=$(state_compare "$current_issues" "$previous_issues")

    # Extract changes
    local new_issues recovered_issues unchanged_issues
    IFS='|' read -r new_issues recovered_issues unchanged_issues <<< "$comparison"

    # Log changes
    [[ -n "$new_issues" ]] && log_warn "New issues: ${new_issues}"
    [[ -n "$recovered_issues" ]] && log_info "Recovered: ${recovered_issues}"
    [[ -n "$unchanged_issues" ]] && log_info "Unchanged: ${unchanged_issues}"

    # Send alerts (smart rate-limiting)
    send_smart_alert "$new_issues" "$recovered_issues" "$unchanged_issues"

    # Save current state
    state_save "$current_issues"

    # Export Prometheus metrics
    local status=0
    [[ -n "$current_issues" ]] && status=2
    export_metrics "$status"

    log_info "Monitoring check completed"
    return 0
}

# ============================================================================
# Script Entry Point
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi
