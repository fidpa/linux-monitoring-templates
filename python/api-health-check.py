#!/usr/bin/env python3
# Copyright (c) 2025-2026 Marc Allgeier (fidpa)
# SPDX-License-Identifier: MIT
# https://github.com/fidpa/linux-monitoring-templates
"""
API Health Check Monitor

Monitors HTTP/HTTPS endpoints and sends alerts on failures.

Features:
- HTTP status code validation
- Response time monitoring
- SSL certificate validation
- Prometheus metrics export

Usage:
    ./api-health-check.py
    API_URL=https://example.com/health ./api-health-check.py

Environment Variables:
    SERVICE_NAME - Service identifier (default: api-health)
    API_URL - URL to monitor (required)
    TIMEOUT - Request timeout in seconds (default: 10)
    EXPECTED_STATUS - Expected HTTP status code (default: 200)

Documentation: https://github.com/fidpa/linux-monitoring-templates
Version: 1.0.1
Created: 2026-01-03
"""

import logging
import os
import socket
import sys
import time
import urllib.request
from pathlib import Path

# Configuration
SERVICE_NAME = os.getenv("SERVICE_NAME", "api-health")
DEVICE_NAME = os.getenv("DEVICE_NAME", socket.gethostname().split('.')[0])
API_URL = os.getenv("API_URL", "")
TIMEOUT = int(os.getenv("TIMEOUT", "10"))
EXPECTED_STATUS = int(os.getenv("EXPECTED_STATUS", "200"))

# Paths
STATE_DIR = Path(os.getenv("STATE_DIR", f"/var/lib/{SERVICE_NAME}"))
LOG_DIR = Path(os.getenv("LOG_DIR", "/var/log"))
METRICS_DIR = Path("/var/lib/node_exporter/textfile_collector")

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


def check_api() -> dict:
    """Check API endpoint health."""
    STATE_DIR.mkdir(parents=True, exist_ok=True)

    if not API_URL:
        logger.error("API_URL not configured")
        return {'status': 'ERROR', 'response_time': 0, 'http_status': 0}

    try:
        start = time.time()
        request = urllib.request.Request(API_URL)

        with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
            response_time = time.time() - start
            http_status = response.status

            if http_status == EXPECTED_STATUS:
                status = 'OK'
                logger.info(f"API OK: {API_URL} ({http_status}, {response_time:.2f}s)")
            else:
                status = 'WARNING'
                logger.warning(f"API status mismatch: {http_status} (expected {EXPECTED_STATUS})")

            return {
                'status': status,
                'response_time': round(response_time, 3),
                'http_status': http_status
            }

    except urllib.error.HTTPError as e:
        logger.error(f"HTTP error: {e.code}")
        return {'status': 'CRITICAL', 'response_time': 0, 'http_status': e.code}

    except urllib.error.URLError as e:
        logger.error(f"URL error: {e.reason}")
        return {'status': 'CRITICAL', 'response_time': 0, 'http_status': 0}

    except Exception as e:
        logger.error(f"Check failed: {e}")
        return {'status': 'ERROR', 'response_time': 0, 'http_status': 0}


def export_metrics(data: dict) -> None:
    """Export Prometheus metrics."""
    if not METRICS_DIR.exists():
        return

    METRICS_FILE.parent.mkdir(parents=True, exist_ok=True)

    status_value = 0
    if data['status'] == 'WARNING':
        status_value = 1
    elif data['status'] in ('CRITICAL', 'ERROR'):
        status_value = 2

    with open(METRICS_FILE, 'w') as f:
        f.write("# HELP api_health_status API health status (0=OK, 1=WARNING, 2=CRITICAL)\n")
        f.write("# TYPE api_health_status gauge\n")
        f.write(f"api_health_status{{url=\"{API_URL}\"}} {status_value}\n\n")

        f.write("# HELP api_response_time_seconds API response time\n")
        f.write("# TYPE api_response_time_seconds gauge\n")
        f.write(f"api_response_time_seconds{{url=\"{API_URL}\"}} {data['response_time']}\n\n")

        f.write("# HELP api_http_status HTTP status code\n")
        f.write("# TYPE api_http_status gauge\n")
        f.write(f"api_http_status{{url=\"{API_URL}\"}} {data['http_status']}\n")

    logger.info("Metrics exported")


def main() -> int:
    """Main entry point."""
    logger.info(f"Starting API health check: {API_URL}")

    try:
        result = check_api()
        export_metrics(result)

        if result['status'] == 'CRITICAL':
            logger.error("CRITICAL: API health check failed")
            return 2
        elif result['status'] in ('WARNING', 'ERROR'):
            logger.warning(f"{result['status']}: API health check issues")
            return 1

        logger.info("API health check completed")
        return 0

    except Exception as e:
        logger.error(f"Check failed: {e}")
        return 1


if __name__ == '__main__':
    sys.exit(main())
