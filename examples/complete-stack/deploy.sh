#!/bin/bash
# Copyright (c) 2025-2026 Marc Allgeier (fidpa)
# SPDX-License-Identifier: MIT
# https://github.com/fidpa/linux-monitoring-templates
#
# Complete Stack Deployment Script
#
# Deploys a full monitoring stack with disk, service, and network monitoring.
# The scripts come from the repository's bash/ templates -- this directory
# holds no copies of them, only the systemd units that wire them up.
#
# Requires a full checkout of the repository (the templates are read from
# ../../bash/), and must run as root.
#
# Usage:
#   sudo ./deploy.sh
#   ./deploy.sh --dry-run
#
# Created: 2026-01-03

set -uo pipefail

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

echo "========================================="
echo "Monitoring Stack Deployment"
echo "========================================="
echo ""

# Configuration
INSTALL_USER="${INSTALL_USER:-monitoring}"
INSTALL_GROUP="${INSTALL_GROUP:-monitoring}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# The monitors this stack deploys, taken straight from the repository's
# templates. There is deliberately no second copy under examples/: until
# v1.2.0 this directory carried its own disk-monitor.sh, which drifted three
# releases behind the real template and lost rate-limiting and atomic writes
# along the way.
#
# generic-monitor.sh is not listed on purpose -- it is a starting point to
# customize, not a monitor with a meaning of its own.
MONITORS=(
    disk-monitor
    service-health-check
    network-monitor
)

# Check if running as root. --dry-run changes nothing, so it must not require
# root -- otherwise the one mode meant for looking before you leap is the one
# mode you cannot run.
if [[ $EUID -ne 0 && "$DRY_RUN" == "false" ]]; then
    echo "ERROR: This script must be run as root (or use --dry-run)"
    exit 1
fi

# Create monitoring user if doesn't exist
if ! id "$INSTALL_USER" &>/dev/null; then
    echo "Creating user: $INSTALL_USER"
    if [[ "$DRY_RUN" == "false" ]]; then
        useradd -r -s /bin/false -d /var/lib/monitoring "$INSTALL_USER"
    fi
fi

# Deploy scripts
echo ""
echo "Deploying monitoring scripts..."
for monitor in "${MONITORS[@]}"; do
    script="${REPO_ROOT}/bash/${monitor}.sh"
    target="/usr/local/bin/${monitor}"

    if [[ ! -f "$script" ]]; then
        echo "ERROR: Template not found: $script"
        echo "       Run this script from a full checkout of the repository."
        exit 1
    fi

    echo "  - bash/${monitor}.sh → $target"
    if [[ "$DRY_RUN" == "false" ]]; then
        cp "$script" "$target"
        chmod 755 "$target"
        chown root:root "$target"
    fi
done

# Deploy systemd units
echo ""
echo "Deploying systemd units..."
for unit in "$SCRIPT_DIR"/systemd/*.{service,timer}; do
    [[ -f "$unit" ]] || continue
    filename=$(basename "$unit")

    echo "  - $filename → /etc/systemd/system/$filename"
    if [[ "$DRY_RUN" == "false" ]]; then
        cp "$unit" /etc/systemd/system/
        chmod 644 /etc/systemd/system/"$filename"
    fi
done

# Reload systemd
if [[ "$DRY_RUN" == "false" ]]; then
    echo ""
    echo "Reloading systemd daemon..."
    systemctl daemon-reload
fi

# Enable and start timers
echo ""
echo "Enabling monitoring timers..."
for timer in "$SCRIPT_DIR"/systemd/*.timer; do
    [[ -f "$timer" ]] || continue
    timer_name=$(basename "$timer")

    echo "  - $timer_name"
    if [[ "$DRY_RUN" == "false" ]]; then
        systemctl enable "$timer_name"
        systemctl start "$timer_name"
    fi
done

# Verify deployment
echo ""
echo "========================================="
echo "Deployment Summary"
echo "========================================="

if [[ "$DRY_RUN" == "false" ]]; then
    # The names below are derived from MONITORS, not typed out a second time.
    # The hardcoded list used to say "service-health" while the unit is called
    # "service-health-check", so the summary reported nothing for it.
    timer_pattern=$(IFS='|'; echo "${MONITORS[*]}")

    echo ""
    echo "Active Timers:"
    systemctl list-timers --no-pager | grep -E "$timer_pattern" || echo "  (none active)"

    echo ""
    echo "Service Status:"
    for service in "${MONITORS[@]}"; do
        if systemctl is-enabled "${service}.timer" &>/dev/null; then
            status=$(systemctl is-active "${service}.timer" || echo "inactive")
            echo "  - ${service}.timer: $status"
        fi
    done

    echo ""
    echo "StateDirectories:"
    for service in "${MONITORS[@]}"; do
        dir="/var/lib/${service}"
        if [[ -d "$dir" ]]; then
            echo "  - $dir (exists)"
        else
            echo "  - $dir (not created yet - will be created on first run)"
        fi
    done
else
    echo ""
    echo "DRY RUN - No changes made"
fi

echo ""
echo "========================================="
echo "Deployment Complete!"
echo "========================================="
echo ""
echo "Next Steps:"
echo "1. Check timer status: systemctl list-timers"
echo "2. Check logs: journalctl -u disk-monitor.service"
echo "3. Manual trigger: systemctl start disk-monitor.service"
echo ""
