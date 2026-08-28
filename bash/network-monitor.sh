#!/bin/bash
# Copyright (c) 2025-2026 Marc Allgeier (fidpa)
# SPDX-License-Identifier: MIT
# https://github.com/fidpa/linux-monitoring-templates
#
# Network Connectivity Monitor
#
# Monitors network connectivity via ping and exports the result as Prometheus
# metrics. Alerting is not built in, see generic-monitor.sh.
#
# Features:
# - Multiple target monitoring (DNS, Gateway, External)
# - Packet loss detection
# - Prometheus metrics export
#
# Usage:
#   ./network-monitor.sh
#   PING_TARGETS="8.8.8.8 1.1.1.1" ./network-monitor.sh
#
# Environment Variables:
#   SERVICE_NAME - Service identifier (default: network-monitor)
#   PING_TARGETS - Space-separated ping targets
#   PING_COUNT - Number of pings per target (default: 3)
#
# Documentation: https://github.com/fidpa/linux-monitoring-templates
# Created: 2026-01-03

set -uo pipefail

# Configuration
readonly SERVICE_NAME="${SERVICE_NAME:-network-monitor}"
readonly DEVICE_NAME="${DEVICE_NAME:-$(hostname -s)}"
readonly PING_TARGETS="${PING_TARGETS:-8.8.8.8 1.1.1.1}"
readonly PING_COUNT="${PING_COUNT:-3}"

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

# Check connectivity
check_connectivity() {
    local unreachable=""
    local total=0
    local reachable=0

    for target in $PING_TARGETS; do
        ((total++))
        if ping -c "$PING_COUNT" -W 2 "$target" >/dev/null 2>&1; then
            ((reachable++))
            log "INFO" "Target ${target} is reachable"
        else
            unreachable="${unreachable}${target},"
            log "WARNING" "Target ${target} is unreachable"
        fi
    done

    unreachable="${unreachable%,}"

    echo "${unreachable}|${total}|${reachable}"
}

# Export metrics
export_metrics() {
    local total="$1"
    local reachable="$2"
    local unreachable="$3"

    # Prometheus export is opt-in: the textfile collector directory is created
    # by the node_exporter setup, not by this script. No directory, no export.
    [[ ! -d "$METRICS_DIR" ]] && return 0

    # Atomic write: build the file beside its target, then rename it into place.
    # A direct write can be scraped half-finished; POSIX rename() cannot.
    local temp_file="${METRICS_FILE}.$$"

    cat > "$temp_file" <<EOF
# HELP network_targets_total Total monitored targets
# TYPE network_targets_total gauge
network_targets_total ${total}

# HELP network_targets_reachable Reachable targets
# TYPE network_targets_reachable gauge
network_targets_reachable ${reachable}

# HELP network_targets_unreachable Unreachable targets
# TYPE network_targets_unreachable gauge
network_targets_unreachable ${unreachable}
EOF

    chmod 644 "$temp_file"
    mv -f "$temp_file" "$METRICS_FILE"

    log "INFO" "Metrics exported: ${reachable}/${total} targets reachable"
}

# Main
main() {
    log "INFO" "Starting network connectivity check"

    local result
    result=$(check_connectivity)

    IFS='|' read -r unreachable_targets total reachable <<< "$result"
    local unreachable=$((total - reachable))

    export_metrics "$total" "$reachable" "$unreachable"

    if [[ -n "$unreachable_targets" ]]; then
        log "CRITICAL" "Unreachable targets: ${unreachable_targets}"
        # Add alerting here
    else
        log "INFO" "All targets reachable (${reachable}/${total})"
    fi

    log "INFO" "Network check completed"
    return 0
}

main "$@"
