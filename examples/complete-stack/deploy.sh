#!/bin/bash
# Copyright (c) 2025-2026 Marc Allgeier (fidpa)
# SPDX-License-Identifier: MIT
# https://github.com/fidpa/linux-monitoring-templates
#
# Complete Stack Deployment Script
#
# Deploys a full monitoring stack with disk, service, and network monitoring.
#
# Usage:
#   ./deploy.sh
#   ./deploy.sh --dry-run
#
# Version: 1.0.0
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

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: This script must be run as root"
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
for script in "$SCRIPT_DIR"/monitors/*.{sh,py}; do
    [[ -f "$script" ]] || continue
    filename=$(basename "$script")
    target="/usr/local/bin/${filename%.*}"

    echo "  - $filename → $target"
    if [[ "$DRY_RUN" == "false" ]]; then
        cp "$script" "$target"
        chmod +x "$target"
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
    echo ""
    echo "Active Timers:"
    systemctl list-timers --no-pager | grep -E "disk-monitor|service-health|network-monitor" || echo "  (none active)"

    echo ""
    echo "Service Status:"
    for service in disk-monitor service-health network-monitor; do
        if systemctl is-enabled "${service}.timer" &>/dev/null; then
            status=$(systemctl is-active "${service}.timer" || echo "inactive")
            echo "  - ${service}.timer: $status"
        fi
    done

    echo ""
    echo "StateDirectories:"
    for dir in /var/lib/disk-monitor /var/lib/service-health /var/lib/network-monitor; do
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
