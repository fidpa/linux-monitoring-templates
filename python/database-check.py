#!/usr/bin/env python3
# Copyright (c) 2025-2026 Marc Allgeier (fidpa)
# SPDX-License-Identifier: MIT
# https://github.com/fidpa/linux-monitoring-templates
"""
Database Connection Monitor

Monitors database connectivity and basic health metrics.

Features:
- Connection testing
- Query execution time monitoring
- Prometheus metrics export

Usage:
    ./database-check.py
    DB_TYPE=postgresql DB_HOST=localhost ./database-check.py

Environment Variables:
    SERVICE_NAME - Service identifier (default: database-check)
    DB_TYPE - Database type: postgresql, mysql, sqlite (default: sqlite)
    DB_HOST - Database host (default: localhost)
    DB_PORT - Database port (default: varies by DB_TYPE)
    DB_NAME - Database name (default: test)
    DB_USER - Database user (optional)
    DB_PASSWORD - Database password (optional)

Documentation: https://github.com/fidpa/linux-monitoring-templates
Version: 1.0.1
Created: 2026-01-03
"""

import logging
import os
import socket
import sys
import time
from pathlib import Path

# Configuration
SERVICE_NAME = os.getenv("SERVICE_NAME", "database-check")
DEVICE_NAME = os.getenv("DEVICE_NAME", socket.gethostname().split('.')[0])
DB_TYPE = os.getenv("DB_TYPE", "sqlite")
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_NAME = os.getenv("DB_NAME", "test")
DB_USER = os.getenv("DB_USER", "")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")

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


def check_database() -> dict:
    """Check database connectivity."""
    STATE_DIR.mkdir(parents=True, exist_ok=True)

    try:
        if DB_TYPE == "sqlite":
            import sqlite3
            start = time.time()
            conn = sqlite3.connect(DB_NAME, timeout=5)
            cursor = conn.cursor()
            cursor.execute("SELECT 1")
            result = cursor.fetchone()
            query_time = time.time() - start
            conn.close()

            if result == (1,):
                logger.info(f"SQLite connection OK ({query_time:.3f}s)")
                return {'status': 'OK', 'query_time': round(query_time, 3), 'connected': 1}

        elif DB_TYPE == "postgresql":
            import psycopg2
            start = time.time()
            conn = psycopg2.connect(
                host=DB_HOST,
                database=DB_NAME,
                user=DB_USER,
                password=DB_PASSWORD,
                connect_timeout=5
            )
            cursor = conn.cursor()
            cursor.execute("SELECT 1")
            result = cursor.fetchone()
            query_time = time.time() - start
            conn.close()

            if result == (1,):
                logger.info(f"PostgreSQL connection OK ({query_time:.3f}s)")
                return {'status': 'OK', 'query_time': round(query_time, 3), 'connected': 1}

        elif DB_TYPE == "mysql":
            import mysql.connector
            start = time.time()
            conn = mysql.connector.connect(
                host=DB_HOST,
                database=DB_NAME,
                user=DB_USER,
                password=DB_PASSWORD,
                connection_timeout=5
            )
            cursor = conn.cursor()
            cursor.execute("SELECT 1")
            result = cursor.fetchone()
            query_time = time.time() - start
            conn.close()

            if result == (1,):
                logger.info(f"MySQL connection OK ({query_time:.3f}s)")
                return {'status': 'OK', 'query_time': round(query_time, 3), 'connected': 1}

        else:
            logger.error(f"Unsupported DB_TYPE: {DB_TYPE}")
            return {'status': 'ERROR', 'query_time': 0, 'connected': 0}

    except ImportError as e:
        logger.error(f"Database driver not installed: {e}")
        return {'status': 'ERROR', 'query_time': 0, 'connected': 0}

    except Exception as e:
        logger.error(f"Database connection failed: {e}")
        return {'status': 'CRITICAL', 'query_time': 0, 'connected': 0}

    return {'status': 'ERROR', 'query_time': 0, 'connected': 0}


def export_metrics(data: dict) -> None:
    """Export Prometheus metrics."""
    if not METRICS_DIR.exists():
        return

    METRICS_FILE.parent.mkdir(parents=True, exist_ok=True)

    status_value = 0 if data['status'] == 'OK' else 2

    with open(METRICS_FILE, 'w') as f:
        f.write("# HELP database_connected Database connection status (1=connected, 0=disconnected)\n")
        f.write("# TYPE database_connected gauge\n")
        f.write(f"database_connected{{type=\"{DB_TYPE}\",host=\"{DB_HOST}\"}} {data['connected']}\n\n")

        f.write("# HELP database_query_time_seconds Database query time\n")
        f.write("# TYPE database_query_time_seconds gauge\n")
        f.write(f"database_query_time_seconds{{type=\"{DB_TYPE}\",host=\"{DB_HOST}\"}} {data['query_time']}\n\n")

        f.write("# HELP database_health_status Database health status (0=OK, 2=CRITICAL)\n")
        f.write("# TYPE database_health_status gauge\n")
        f.write(f"database_health_status{{type=\"{DB_TYPE}\",host=\"{DB_HOST}\"}} {status_value}\n")

    logger.info("Metrics exported")


def main() -> int:
    """Main entry point."""
    logger.info(f"Starting database check: {DB_TYPE} on {DB_HOST}")

    try:
        result = check_database()
        export_metrics(result)

        if result['status'] == 'CRITICAL':
            logger.error("CRITICAL: Database connection failed")
            return 2
        elif result['status'] == 'ERROR':
            logger.error("ERROR: Database check failed")
            return 1

        logger.info("Database check completed")
        return 0

    except Exception as e:
        logger.error(f"Check failed: {e}")
        return 1


if __name__ == '__main__':
    sys.exit(main())
