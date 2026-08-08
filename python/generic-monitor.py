#!/usr/bin/env python3
# Copyright (c) 2025-2026 Marc Allgeier (fidpa)
# SPDX-License-Identifier: MIT
# https://github.com/fidpa/linux-monitoring-templates
"""
Generic Monitoring Script Template - Python Version

Production-ready template for creating monitoring scripts with:
- WARNING/CRITICAL thresholds (configurable)
- Alert cooldown with rate-limiting (prevents spam)
- Telegram integration with actionable messages
- Prometheus metrics export
- Reboot-aware grace period
- StateDirectory for persistent rate-limiting

Usage:
    ./generic-monitor.py
    ./generic-monitor.py --dry-run
    ./generic-monitor.py --verbose

Documentation: https://github.com/fidpa/linux-monitoring-templates/blob/main/docs/SETUP.md
Created: 2026-01-03
"""

import logging
import os
import socket
import sys
import tempfile
import time
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

# ===== Configuration =====

# Service configuration (customize these)
SERVICE_NAME = os.getenv("SERVICE_NAME", "generic-monitor")
DEVICE_NAME = os.getenv("DEVICE_NAME", socket.gethostname().split('.')[0])

# Thresholds (customize for your monitoring use case)
WARNING_THRESHOLD = int(os.getenv("WARNING_THRESHOLD", "75"))
CRITICAL_THRESHOLD = int(os.getenv("CRITICAL_THRESHOLD", "90"))
RECOVERY_THRESHOLD = int(os.getenv("RECOVERY_THRESHOLD", "50"))

# Paths - CRITICAL: StateDirectory for persistent rate-limiting
# ⚠️ NEVER use /run/ for STATE_DIR - it's ephemeral (tmpfs)!
# ✅ ALWAYS use /var/lib/ for STATE_DIR - it's persistent
STATE_DIR = Path(os.getenv("STATE_DIR", f"/var/lib/{SERVICE_NAME}"))
METRICS_DIR = Path(os.getenv("METRICS_DIR", "/var/lib/node_exporter/textfile_collector"))
LOG_DIR = Path(os.getenv("LOG_DIR", "/var/log"))

# Derived paths
METRICS_FILE = METRICS_DIR / f"{SERVICE_NAME}.prom"
LOG_FILE = LOG_DIR / f"{SERVICE_NAME}.log"
SECRETS_FILE = Path(os.getenv("SECRETS_FILE", os.path.expanduser("~/.env.secrets")))

# Alert cooldown (6 hours = 21600 seconds)
ALERT_COOLDOWN = int(os.getenv("ALERT_COOLDOWN", "21600"))

# Reboot grace period (5 minutes = 300 seconds)
REBOOT_GRACE_PERIOD = int(os.getenv("REBOOT_GRACE_PERIOD", "300"))

# Telegram configuration (loaded from secrets file)
TELEGRAM_PREFIX = f"[{DEVICE_NAME.upper()}] {SERVICE_NAME}"
TELEGRAM_BOT_TOKEN = ""
TELEGRAM_CHAT_ID = ""

# ===== Logging Setup =====
logger = logging.getLogger(__name__)

# Configure dual logging (file + stderr for systemd journald)
LOG_FILE.parent.mkdir(parents=True, exist_ok=True)

file_handler = logging.FileHandler(LOG_FILE, mode='a')
file_handler.setLevel(logging.INFO)
file_handler.setFormatter(logging.Formatter(
    '%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
))

console_handler = logging.StreamHandler(sys.stderr)
console_handler.setLevel(logging.INFO)
console_handler.setFormatter(logging.Formatter('%(levelname)s: %(message)s'))

logger.addHandler(file_handler)
logger.addHandler(console_handler)
logger.setLevel(logging.INFO)


# ===== Helper Functions =====

def load_telegram_config() -> bool:
    """Load Telegram configuration from secrets file."""
    global TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID

    if not SECRETS_FILE.exists():
        logger.warning(f"Secrets file not found: {SECRETS_FILE} - Telegram alerts disabled")
        return False

    try:
        with open(SECRETS_FILE) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue

                if '=' in line:
                    key, value = line.split('=', 1)
                    key = key.strip()
                    value = value.strip()

                    if key == 'TELEGRAM_BOT_TOKEN':
                        TELEGRAM_BOT_TOKEN = value
                    elif key == 'TELEGRAM_CHAT_ID':
                        TELEGRAM_CHAT_ID = value

        if not TELEGRAM_BOT_TOKEN or not TELEGRAM_CHAT_ID:
            logger.warning("Missing Telegram credentials - alerts disabled")
            return False

        return True

    except Exception as e:
        logger.error(f"Failed to load Telegram config: {e}")
        return False


def get_uptime_seconds() -> int:
    """Get system uptime in seconds."""
    try:
        with open('/proc/uptime') as f:
            uptime_str = f.read().split()[0]
            return int(float(uptime_str))
    except Exception as e:
        logger.warning(f"Failed to read uptime: {e}")
        return 0


def is_in_reboot_grace_period() -> bool:
    """Check if system is within reboot grace period."""
    uptime = get_uptime_seconds()
    if uptime < REBOOT_GRACE_PERIOD:
        logger.info(f"System in reboot grace period (uptime: {uptime}s < {REBOOT_GRACE_PERIOD}s)")
        return True
    return False


def should_send_alert(alert_level: str) -> bool:
    """
    Check if alert should be sent based on rate limiting cooldown.

    Rate-limiting relies on STATE_DIR being persistent (/var/lib/)!
    If STATE_DIR is ephemeral (/run/), this function will ALWAYS return True
    after service restart → Alert spam.
    """
    alert_file = STATE_DIR / f"last_alert_{alert_level}"
    current_time = int(time.time())

    if alert_file.exists():
        try:
            last_alert_str = alert_file.read_text().strip()
            last_alert = int(last_alert_str)

            time_diff = current_time - last_alert

            if time_diff < ALERT_COOLDOWN:
                remaining = ALERT_COOLDOWN - time_diff
                logger.info(f"Rate limited: {alert_level} alert skipped ({time_diff}s ago, {remaining}s remaining)")
                return False

        except (ValueError, OSError) as e:
            logger.warning(f"Failed to read last alert time: {e}")

    return True


def record_alert(alert_level: str) -> None:
    """Record alert timestamp for rate limiting."""
    alert_file = STATE_DIR / f"last_alert_{alert_level}"
    current_time = int(time.time())

    try:
        alert_file.write_text(str(current_time))
        logger.info(f"Recorded alert timestamp: {alert_level} at {current_time}")
    except OSError as e:
        logger.error(f"Failed to record alert timestamp: {e}")


def send_telegram_alert(message: str, emoji: str = "⚠️") -> bool:
    """Send Telegram alert message."""
    if not TELEGRAM_BOT_TOKEN or not TELEGRAM_CHAT_ID:
        logger.warning("Telegram not configured - alert not sent")
        return False

    try:
        full_message = f"{emoji} {TELEGRAM_PREFIX}\n\n{message}"
        url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"
        data = urllib.parse.urlencode({
            'chat_id': TELEGRAM_CHAT_ID,
            'text': full_message,
            'parse_mode': 'Markdown'
        }).encode('utf-8')

        request = urllib.request.Request(url, data=data)
        with urllib.request.urlopen(request, timeout=10) as response:
            if response.status == 200:
                logger.info(f"Telegram alert sent: {message[:50]}...")
                return True
            else:
                logger.error(f"Telegram API error: HTTP {response.status}")
                return False

    except Exception as e:
        logger.error(f"Failed to send Telegram alert: {e}")
        return False


def export_prometheus_metrics(metrics_data: dict[str, Any]) -> None:
    """Export Prometheus metrics to textfile collector."""
    # Prometheus export is opt-in: the textfile collector directory is created
    # by the node_exporter setup, not by this script. No directory, no export.
    if not METRICS_DIR.exists():
        return

    try:
        # Atomic write: build the file beside its target, then rename it into
        # place. A direct write can be scraped half-finished; os.replace() cannot.
        with tempfile.NamedTemporaryFile(
            mode='w',
            dir=METRICS_FILE.parent,
            prefix=f'.{METRICS_FILE.name}.',
            suffix='.tmp',
            delete=False,
        ) as f:
            temp_path = f.name
            f.write(f"# HELP {SERVICE_NAME}_status Monitoring status (0=OK, 1=WARNING, 2=CRITICAL)\n")
            f.write(f"# TYPE {SERVICE_NAME}_status gauge\n")
            f.write(f"{SERVICE_NAME}_status {metrics_data.get('status', 0)}\n")
            f.write("\n")

            for key, value in metrics_data.items():
                if key != 'status':
                    f.write(f"# HELP {SERVICE_NAME}_{key} {SERVICE_NAME} {key}\n")
                    f.write(f"# TYPE {SERVICE_NAME}_{key} gauge\n")
                    f.write(f"{SERVICE_NAME}_{key} {value}\n")
                    f.write("\n")

        os.chmod(temp_path, 0o644)
        os.replace(temp_path, METRICS_FILE)

        logger.info(f"Prometheus metrics exported to {METRICS_FILE}")

    except Exception as e:
        logger.error(f"Failed to export Prometheus metrics: {e}")


# ===== Monitoring Logic (CUSTOMIZE THIS) =====

def check_resource() -> dict[str, Any]:
    """
    Check resource status (customize for your monitoring use case).

    Example implementations:
        - Disk usage: os.statvfs()
        - CPU usage: psutil.cpu_percent()
        - Memory usage: psutil.virtual_memory()
        - Service status: subprocess.run(['systemctl', 'status', 'service'])
        - Log analysis: grep through log files
        - Network connectivity: ping/curl tests
    """
    # TODO: Replace with actual monitoring logic
    # This is just an example placeholder

    # Example: Simulate checking percentage of something
    current_value = 65  # Replace with real check
    max_value = 100

    percent = int((current_value / max_value) * 100)

    status = 'OK'
    if percent >= CRITICAL_THRESHOLD:
        status = 'CRITICAL'
    elif percent >= WARNING_THRESHOLD:
        status = 'WARNING'

    return {
        'percent': percent,
        'current': current_value,
        'max': max_value,
        'status': status
    }


# ===== Main Function =====

def main() -> int:
    """Main entry point for the monitoring script."""
    # CRITICAL: Initialize state directory (persistent!)
    STATE_DIR.mkdir(parents=True, exist_ok=True)

    # Load Telegram configuration
    load_telegram_config()

    # Check if in reboot grace period
    if is_in_reboot_grace_period():
        logger.info("Skipping check during reboot grace period")
        return 0

    logger.info(f"Starting {SERVICE_NAME} check (WARNING: {WARNING_THRESHOLD}%, CRITICAL: {CRITICAL_THRESHOLD}%)")

    # Check resource
    try:
        result = check_resource()
    except Exception as e:
        logger.error(f"Failed to check resource: {e}")
        return 1

    percent = result.get('percent', 0)
    status = result.get('status', 'UNKNOWN')

    logger.info(f"{SERVICE_NAME} status: {status} ({percent}%)")

    # Determine alert level
    alert_level = 0  # 0=OK, 1=WARNING, 2=CRITICAL
    alert_type = "OK"
    emoji = ""

    if percent >= CRITICAL_THRESHOLD:
        alert_level = 2
        alert_type = "CRITICAL"
        emoji = "🔴"
    elif percent >= WARNING_THRESHOLD:
        alert_level = 1
        alert_type = "WARNING"
        emoji = "🟡"
    elif percent < RECOVERY_THRESHOLD and STATE_DIR.exists():
        # Check if we previously had a WARNING/CRITICAL alert
        if (STATE_DIR / "last_alert_WARNING").exists() or (STATE_DIR / "last_alert_CRITICAL").exists():
            alert_type = "RECOVERY"
            emoji = "✅"

    # Export Prometheus metrics (always)
    export_prometheus_metrics({
        'status': alert_level,
        'percent': percent,
        'value': result.get('current', 0)
    })

    # Send alert if threshold exceeded
    if alert_level > 0 or alert_type == "RECOVERY":
        logger.warning(f"{alert_type}: {SERVICE_NAME} at {percent}%")

        if should_send_alert(alert_type):
            message = f"*{alert_type}*: Resource at {percent}%\n"
            message += f"Current: {result.get('current', 'N/A')}\n"
            message += f"Max: {result.get('max', 'N/A')}\n"
            message += "\n🔧 *Actions*:\n"
            message += "- Check resource usage\n"
            message += "- Review logs\n"

            if send_telegram_alert(message, emoji):
                record_alert(alert_type)
                logger.info(f"{alert_type} alert sent")
            else:
                logger.error(f"Failed to send {alert_type} alert")
        else:
            logger.info(f"{alert_type} alert skipped (rate limiting active)")

    # Cleanup old alert timestamps
    if alert_level == 0 and alert_type == "OK":
        for old_alert in ["WARNING", "CRITICAL", "RECOVERY"]:
            old_file = STATE_DIR / f"last_alert_{old_alert}"
            if old_file.exists():
                try:
                    old_file.unlink()
                    logger.info(f"Cleared old alert timestamp: {old_alert}")
                except OSError as e:
                    logger.warning(f"Failed to clear old alert timestamp: {e}")

    logger.info(f"{SERVICE_NAME} check completed")
    return 0


if __name__ == '__main__':
    sys.exit(main())
