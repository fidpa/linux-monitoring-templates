#!/usr/bin/env python3
# Copyright (c) 2025-2026 Marc Allgeier (fidpa)
# SPDX-License-Identifier: MIT
# https://github.com/fidpa/linux-monitoring-templates
"""
Process Monitor

Monitors process CPU/memory usage and exports the result as Prometheus metrics.
Alerting is not built in, see generic-monitor.py.

Features:
- CPU and memory threshold monitoring
- Process existence checks
- Prometheus metrics export

Usage:
    ./process-monitor.py
    PROCESS_NAME=nginx ./process-monitor.py

Environment Variables:
    SERVICE_NAME - Service identifier (default: process-monitor)
    PROCESS_NAME - Process name to monitor (default: python3)
    CPU_THRESHOLD - CPU threshold percentage (default: 80)
    MEM_THRESHOLD - Memory threshold percentage (default: 80)

Documentation: https://github.com/fidpa/linux-monitoring-templates
Created: 2026-01-03
"""

import logging
import os
import socket
import sys
import tempfile
from pathlib import Path

import psutil

# Configuration
SERVICE_NAME = os.getenv("SERVICE_NAME", "process-monitor")
DEVICE_NAME = os.getenv("DEVICE_NAME", socket.gethostname().split('.')[0])
PROCESS_NAME = os.getenv("PROCESS_NAME", "python3")
CPU_THRESHOLD = int(os.getenv("CPU_THRESHOLD", "80"))
MEM_THRESHOLD = int(os.getenv("MEM_THRESHOLD", "80"))

# Paths
STATE_DIR = Path(os.getenv("STATE_DIR", f"/var/lib/{SERVICE_NAME}"))
LOG_DIR = Path(os.getenv("LOG_DIR", "/var/log"))
METRICS_DIR = Path(os.getenv("METRICS_DIR", "/var/lib/node_exporter/textfile_collector"))

LOG_FILE = LOG_DIR / f"{SERVICE_NAME}.log"
METRICS_FILE = METRICS_DIR / f"{SERVICE_NAME}.prom"

# Setup logging
LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler(sys.stderr)
    ]
)
logger = logging.getLogger(__name__)


def find_processes(name: str) -> list[psutil.Process]:
    """Find all processes matching name."""
    processes = []
    for proc in psutil.process_iter(['name', 'cpu_percent', 'memory_percent']):
        try:
            if name.lower() in proc.info['name'].lower():
                processes.append(proc)
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue
    return processes


def check_process() -> dict:
    """Check process resource usage."""
    STATE_DIR.mkdir(parents=True, exist_ok=True)

    processes = find_processes(PROCESS_NAME)

    if not processes:
        logger.warning(f"No processes found matching: {PROCESS_NAME}")
        return {'status': 'NOT_FOUND', 'count': 0, 'cpu': 0, 'memory': 0}

    total_cpu = sum(p.cpu_percent(interval=0.1) for p in processes)
    total_mem = sum(p.memory_percent() for p in processes)

    status = 'OK'
    if total_cpu >= CPU_THRESHOLD or total_mem >= MEM_THRESHOLD:
        status = 'CRITICAL'

    logger.info(f"Process {PROCESS_NAME}: {len(processes)} instances, CPU: {total_cpu:.1f}%, MEM: {total_mem:.1f}%")

    return {
        'status': status,
        'count': len(processes),
        'cpu': round(total_cpu, 2),
        'memory': round(total_mem, 2)
    }


def export_metrics(data: dict) -> None:
    """Export Prometheus metrics."""
    # Prometheus export is opt-in: the textfile collector directory is created
    # by the node_exporter setup, not by this script. No directory, no export.
    if not METRICS_DIR.exists():
        return

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
        f.write(f"# HELP process_count Number of {PROCESS_NAME} processes\n")
        f.write("# TYPE process_count gauge\n")
        f.write(f"process_count{{name=\"{PROCESS_NAME}\"}} {data['count']}\n\n")

        f.write("# HELP process_cpu_percent Total CPU usage\n")
        f.write("# TYPE process_cpu_percent gauge\n")
        f.write(f"process_cpu_percent{{name=\"{PROCESS_NAME}\"}} {data['cpu']}\n\n")

        f.write("# HELP process_memory_percent Total memory usage\n")
        f.write("# TYPE process_memory_percent gauge\n")
        f.write(f"process_memory_percent{{name=\"{PROCESS_NAME}\"}} {data['memory']}\n")

    os.chmod(temp_path, 0o644)
    os.replace(temp_path, METRICS_FILE)

    logger.info("Metrics exported")


def main() -> int:
    """Main entry point."""
    logger.info(f"Starting process monitor for: {PROCESS_NAME}")

    try:
        result = check_process()
        export_metrics(result)

        if result['status'] == 'CRITICAL':
            logger.warning(f"CRITICAL: {PROCESS_NAME} exceeds thresholds")
            return 2
        elif result['status'] == 'NOT_FOUND':
            logger.error(f"ERROR: Process {PROCESS_NAME} not found")
            return 1

        logger.info("Process check completed")
        return 0

    except Exception as e:
        logger.error(f"Check failed: {e}")
        return 1


if __name__ == '__main__':
    sys.exit(main())
