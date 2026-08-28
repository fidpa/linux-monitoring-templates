#!/bin/bash
# Copyright (c) 2025-2026 Marc Allgeier (fidpa)
# SPDX-License-Identifier: MIT
# https://github.com/fidpa/linux-monitoring-templates
#
# Disk Usage Monitor
#
# Monitors disk usage and exports the result as Prometheus metrics.
# Alerting is not built in, see generic-monitor.sh.
#
# Features:
# - Configurable WARNING/CRITICAL thresholds
# - Prometheus metrics export
#
# Usage:
#   ./disk-monitor.sh
#   SERVICE_NAME=disk-monitor ./disk-monitor.sh
#
# Environment Variables:
#   SERVICE_NAME - Service identifier (default: disk-monitor)
#   WARNING_THRESHOLD - Warning threshold percentage (default: 80)
#   CRITICAL_THRESHOLD - Critical threshold percentage (default: 90)
#   MOUNT_POINT - Mount point to monitor (default: /)
#
# Documentation: https://github.com/fidpa/linux-monitoring-templates
# Created: 2026-01-03

set -uo pipefail

# Configuration
readonly SERVICE_NAME="${SERVICE_NAME:-disk-monitor}"
readonly DEVICE_NAME="${DEVICE_NAME:-$(hostname -s)}"
readonly WARNING_THRESHOLD="${WARNING_THRESHOLD:-80}"
readonly CRITICAL_THRESHOLD="${CRITICAL_THRESHOLD:-90}"
readonly MOUNT_POINT="${MOUNT_POINT:-/}"

# Paths
readonly STATE_DIR="${STATE_DIR:-/var/lib/${SERVICE_NAME}}"
readonly LOG_DIR="${LOG_DIR:-/var/log}"
readonly METRICS_DIR="${METRICS_DIR:-/var/lib/node_exporter/textfile_collector}"

readonly LOG_FILE="${LOG_DIR}/${SERVICE_NAME}.log"
readonly METRICS_FILE="${METRICS_DIR}/${SERVICE_NAME}.prom"

# Create directories
mkdir -p "$STATE_DIR" "$LOG_DIR"

# Logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [${1}] ${2}" | tee -a "$LOG_FILE" >&2
}

# Check disk usage
check_disk() {
    local usage
    usage=$(df "$MOUNT_POINT" | awk 'NR==2 {print $5}' | tr -d '%')

    if [[ -z "$usage" ]]; then
        log "ERROR" "Failed to read disk usage for ${MOUNT_POINT}"
        return 1
    fi

    echo "$usage"
}

# Determine status
get_status() {
    local usage="$1"

    if (( usage >= CRITICAL_THRESHOLD )); then
        echo "CRITICAL"
    elif (( usage >= WARNING_THRESHOLD )); then
        echo "WARNING"
    else
        echo "OK"
    fi
}

# Export metrics
export_metrics() {
    local usage="$1"
    local status="$2"

    # Prometheus export is opt-in: the textfile collector directory is created
    # by the node_exporter setup, not by this script. No directory, no export.
    [[ ! -d "$METRICS_DIR" ]] && return 0

    local status_value=0
    case "$status" in
        CRITICAL) status_value=2 ;;
        WARNING) status_value=1 ;;
        OK) status_value=0 ;;
        *) status_value=3 ;;  # UNKNOWN/ERROR
    esac

    # Atomic write: build the file beside its target, then rename it into place.
    # A direct write can be scraped half-finished; POSIX rename() cannot.
    local temp_file="${METRICS_FILE}.$$"

    cat > "$temp_file" <<EOF
# HELP disk_usage_percent Disk usage percentage
# TYPE disk_usage_percent gauge
disk_usage_percent{mount="${MOUNT_POINT}"} ${usage}

# HELP disk_monitor_status Disk monitor status (0=OK, 1=WARNING, 2=CRITICAL, 3=UNKNOWN)
# TYPE disk_monitor_status gauge
disk_monitor_status ${status_value}
EOF

    chmod 644 "$temp_file"
    mv -f "$temp_file" "$METRICS_FILE"

    log "INFO" "Metrics exported: ${MOUNT_POINT} at ${usage}%"
}

# Main
main() {
    log "INFO" "Starting disk usage check for ${MOUNT_POINT}"

    local usage
    if ! usage=$(check_disk); then
        export_metrics 0 "ERROR"
        return 1
    fi

    local status
    status=$(get_status "$usage")

    log "INFO" "Disk usage: ${usage}% (${status})"

    export_metrics "$usage" "$status"

    if [[ "$status" != "OK" ]]; then
        log "WARNING" "${status}: ${MOUNT_POINT} at ${usage}%"
        # Add alerting here (e.g., send_telegram_alert from generic-monitor.sh)
    fi

    log "INFO" "Disk check completed"
    return 0
}

main "$@"
