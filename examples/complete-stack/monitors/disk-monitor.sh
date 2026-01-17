#!/bin/bash
# Example: Disk Usage Monitor (production-ready)
set -uo pipefail

SERVICE_NAME="disk-monitor"
DEVICE_NAME="$(hostname -s)"
MOUNT_POINT="/"
WARNING_THRESHOLD=80
CRITICAL_THRESHOLD=90

STATE_DIR="/var/lib/${SERVICE_NAME}"
LOG_FILE="/var/log/${SERVICE_NAME}.log"
METRICS_FILE="/var/lib/node_exporter/textfile_collector/${SERVICE_NAME}.prom"

mkdir -p "$STATE_DIR"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [${1}] ${2}" | tee -a "$LOG_FILE" >&2
}

usage=$(df "$MOUNT_POINT" | awk 'NR==2 {print $5}' | tr -d '%')
status=0

if (( usage >= CRITICAL_THRESHOLD )); then
    status=2
    log "CRITICAL" "Disk usage at ${usage}% (threshold: ${CRITICAL_THRESHOLD}%)"
elif (( usage >= WARNING_THRESHOLD )); then
    status=1
    log "WARNING" "Disk usage at ${usage}% (threshold: ${WARNING_THRESHOLD}%)"
else
    log "INFO" "Disk usage OK: ${usage}%"
fi

# Export Prometheus metrics
if [[ -d "$(dirname "$METRICS_FILE")" ]]; then
    cat > "$METRICS_FILE" <<EOF
# HELP disk_usage_percent Disk usage percentage
# TYPE disk_usage_percent gauge
disk_usage_percent{mount="${MOUNT_POINT}"} ${usage}

# HELP disk_monitor_status Status (0=OK, 1=WARNING, 2=CRITICAL)
# TYPE disk_monitor_status gauge
disk_monitor_status ${status}
EOF
fi

exit $status
