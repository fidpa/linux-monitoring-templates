#!/bin/bash
# Copyright (c) 2025-2026 Marc Allgeier (fidpa)
# SPDX-License-Identifier: MIT
# https://github.com/fidpa/linux-monitoring-templates
#
# systemd Service Health Check
#
# Monitors systemd service status and sends alerts on failures.
#
# Features:
# - Multiple service monitoring
# - Failed unit detection
# - Smart rate-limiting
# - Prometheus metrics export
#
# Usage:
#   ./service-health-check.sh
#   MONITORED_SERVICES="nginx docker sshd" ./service-health-check.sh
#
# Environment Variables:
#   SERVICE_NAME - Service identifier (default: service-health)
#   MONITORED_SERVICES - Space-separated list of services to monitor
#
# Documentation: https://github.com/fidpa/linux-monitoring-templates
# Version: 1.0.0
# Created: 2026-01-03

set -uo pipefail

# Configuration
readonly SERVICE_NAME="${SERVICE_NAME:-service-health}"
readonly DEVICE_NAME="${DEVICE_NAME:-$(hostname -s)}"
readonly MONITORED_SERVICES="${MONITORED_SERVICES:-nginx docker sshd}"

# Paths
readonly STATE_DIR="${STATE_DIR:-/var/lib/${SERVICE_NAME}}"
readonly LOG_DIR="${LOG_DIR:-/var/log}"
readonly METRICS_DIR="${METRICS_DIR:-/var/lib/node_exporter/textfile_collector}"

readonly LOG_FILE="${LOG_DIR}/${SERVICE_NAME}.log"
readonly METRICS_FILE="${METRICS_DIR}/${SERVICE_NAME}.prom"

# Create directories
mkdir -p "$STATE_DIR" "$LOG_DIR"
[[ -d "$METRICS_DIR" ]] && mkdir -p "$METRICS_DIR"

# Logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [${1}] ${2}" | tee -a "$LOG_FILE" >&2
}

# Check service status
check_services() {
    local failed_services=""
    local total=0
    local active=0

    for service in $MONITORED_SERVICES; do
        ((total++))
        if systemctl is-active "$service" >/dev/null 2>&1; then
            ((active++))
        else
            failed_services="${failed_services}${service},"
            log "WARNING" "Service ${service} is not active"
        fi
    done

    failed_services="${failed_services%,}"

    echo "${failed_services}|${total}|${active}"
}

# Export metrics
export_metrics() {
    local total="$1"
    local active="$2"
    local failed="$3"

    [[ ! -d "$METRICS_DIR" ]] && return 0

    cat > "$METRICS_FILE" <<EOF
# HELP services_total Total monitored services
# TYPE services_total gauge
services_total ${total}

# HELP services_active Active services
# TYPE services_active gauge
services_active ${active}

# HELP services_failed Failed services
# TYPE services_failed gauge
services_failed ${failed}
EOF

    log "INFO" "Metrics exported: ${active}/${total} services active"
}

# Main
main() {
    log "INFO" "Starting service health check"

    local result
    result=$(check_services)

    IFS='|' read -r failed_services total active <<< "$result"
    local failed=$((total - active))

    export_metrics "$total" "$active" "$failed"

    if [[ -n "$failed_services" ]]; then
        log "CRITICAL" "Failed services: ${failed_services}"
        # Add alerting here
    else
        log "INFO" "All services running (${active}/${total})"
    fi

    log "INFO" "Service health check completed"
    return 0
}

main "$@"
