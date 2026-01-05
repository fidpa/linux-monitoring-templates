# Device Profiles for Multi-Server Monitoring

Adapt monitoring templates for different server types using device profiles.

## Overview

Instead of hardcoding device-specific paths and settings, use **device profiles** to:
- Reuse same monitoring script across multiple servers
- Automatically detect server type (via hostname or config)
- Apply server-specific configuration (paths, thresholds, etc.)

## Pattern

### Bash Example

```bash
#!/bin/bash
set -uo pipefail

# Detect device from hostname
detect_device() {
    local hostname=$(hostname -s)

    case "$hostname" in
        web-*)
            echo "web-server"
            ;;
        db-*)
            echo "database"
            ;;
        cache-*)
            echo "cache"
            ;;
        *)
            echo "generic"
            ;;
    esac
}

# Get device-specific configuration
get_device_config() {
    local device="$1"

    case "$device" in
        web-server)
            STATE_DIR="/var/lib/web-monitor"
            LOG_DIR="/var/log/web"
            CRITICAL_THRESHOLD=90
            ;;
        database)
            STATE_DIR="/var/lib/db-monitor"
            LOG_DIR="/var/log/database"
            CRITICAL_THRESHOLD=85
            ;;
        cache)
            STATE_DIR="/var/lib/cache-monitor"
            LOG_DIR="/var/log/cache"
            CRITICAL_THRESHOLD=95
            ;;
        generic)
            STATE_DIR="/var/lib/monitor"
            LOG_DIR="/var/log"
            CRITICAL_THRESHOLD=80
            ;;
    esac

    export STATE_DIR LOG_DIR CRITICAL_THRESHOLD
}

# Main
DEVICE=$(detect_device)
get_device_config "$DEVICE"

echo "Device: $DEVICE"
echo "STATE_DIR: $STATE_DIR"
echo "CRITICAL_THRESHOLD: $CRITICAL_THRESHOLD"
```

### Python Example

```python
#!/usr/bin/env python3
import os
import socket
from pathlib import Path
from typing import Dict, Any

# Device profiles configuration
DEVICE_PROFILES: Dict[str, Dict[str, Any]] = {
    'web-server': {
        'name': 'Web Server',
        'state_dir': Path('/var/lib/web-monitor'),
        'log_dir': Path('/var/log/web'),
        'critical_threshold': 90,
        'warning_threshold': 75,
    },
    'database': {
        'name': 'Database Server',
        'state_dir': Path('/var/lib/db-monitor'),
        'log_dir': Path('/var/log/database'),
        'critical_threshold': 85,
        'warning_threshold': 70,
    },
    'cache': {
        'name': 'Cache Server',
        'state_dir': Path('/var/lib/cache-monitor'),
        'log_dir': Path('/var/log/cache'),
        'critical_threshold': 95,
        'warning_threshold': 80,
    },
    'generic': {
        'name': 'Generic Server',
        'state_dir': Path('/var/lib/monitor'),
        'log_dir': Path('/var/log'),
        'critical_threshold': 80,
        'warning_threshold': 65,
    },
}

def detect_device() -> str:
    """Detect device type from hostname."""
    hostname = socket.gethostname().split('.')[0].lower()

    if hostname.startswith('web-'):
        return 'web-server'
    elif hostname.startswith('db-'):
        return 'database'
    elif hostname.startswith('cache-'):
        return 'cache'
    else:
        return 'generic'

def get_device_profile(device: str) -> Dict[str, Any]:
    """Get device profile configuration."""
    return DEVICE_PROFILES.get(device, DEVICE_PROFILES['generic'])

# Main
device = detect_device()
profile = get_device_profile(device)

print(f"Device: {profile['name']}")
print(f"STATE_DIR: {profile['state_dir']}")
print(f"CRITICAL_THRESHOLD: {profile['critical_threshold']}")
```

## Configuration File Approach

Instead of hardcoding profiles, use a configuration file:

**`/etc/monitoring/device-profile.conf`:**
```ini
[general]
device_type = web-server
hostname = web01.example.com

[paths]
state_dir = /var/lib/web-monitor
log_dir = /var/log/web
metrics_dir = /var/lib/node_exporter/textfile_collector

[thresholds]
disk_warning = 75
disk_critical = 90
cpu_warning = 70
cpu_critical = 85
memory_warning = 80
memory_critical = 90
```

**Load config in Python:**
```python
import configparser

config = configparser.ConfigParser()
config.read('/etc/monitoring/device-profile.conf')

DEVICE_TYPE = config.get('general', 'device_type', fallback='generic')
STATE_DIR = Path(config.get('paths', 'state_dir', fallback='/var/lib/monitor'))
DISK_CRITICAL = config.getint('thresholds', 'disk_critical', fallback=80)
```

**Load config in Bash:**
```bash
source /etc/monitoring/device-profile.conf

# Or parse manually
DEVICE_TYPE=$(grep '^device_type' /etc/monitoring/device-profile.conf | cut -d= -f2 | xargs)
STATE_DIR=$(grep '^state_dir' /etc/monitoring/device-profile.conf | cut -d= -f2 | xargs)
```

## Environment Variable Approach

Pass configuration via environment variables:

**systemd service:**
```ini
[Service]
Environment="DEVICE_TYPE=web-server"
Environment="STATE_DIR=/var/lib/web-monitor"
Environment="CRITICAL_THRESHOLD=90"
ExecStart=/usr/local/bin/monitor.py
```

**Script:**
```python
import os

DEVICE_TYPE = os.getenv("DEVICE_TYPE", "generic")
STATE_DIR = Path(os.getenv("STATE_DIR", "/var/lib/monitor"))
CRITICAL_THRESHOLD = int(os.getenv("CRITICAL_THRESHOLD", "80"))
```

## Graceful Fallback

Always provide defaults for unknown devices:

```python
def get_device_profile(device: str) -> Dict[str, Any]:
    """Get device profile with graceful fallback."""
    profile = DEVICE_PROFILES.get(device)

    if not profile:
        print(f"Warning: Unknown device '{device}', using generic profile")
        profile = DEVICE_PROFILES['generic']

    return profile
```

## Real-World Example

**Scenario**: Monitor disk usage across web, database, and cache servers.

**Requirements**:
- Web servers: Alert at 90% (high traffic, expected)
- Database servers: Alert at 85% (write-heavy, less tolerance)
- Cache servers: Alert at 95% (read-heavy, can tolerate more)

**Implementation:**
```python
#!/usr/bin/env python3
import socket
import shutil
from pathlib import Path

# Device profiles
PROFILES = {
    'web-server': {'threshold': 90, 'service': 'nginx'},
    'database': {'threshold': 85, 'service': 'postgresql'},
    'cache': {'threshold': 95, 'service': 'redis'},
}

def detect_device() -> str:
    """Auto-detect device from hostname."""
    hostname = socket.gethostname().split('.')[0]
    if hostname.startswith('web'):
        return 'web-server'
    elif hostname.startswith('db'):
        return 'database'
    elif hostname.startswith('cache'):
        return 'cache'
    return 'generic'

def check_disk(device: str) -> None:
    """Check disk usage with device-specific threshold."""
    profile = PROFILES.get(device, {'threshold': 80, 'service': 'unknown'})

    usage = shutil.disk_usage("/")
    percent = (usage.used / usage.total) * 100

    if percent >= profile['threshold']:
        print(f"CRITICAL: Disk at {percent:.1f}% (threshold: {profile['threshold']}%)")
        print(f"Device type: {device}")
        print(f"Service: {profile['service']}")
        return 2
    else:
        print(f"OK: Disk at {percent:.1f}%")
        return 0

# Main
device = detect_device()
exit(check_disk(device))
```

## Benefits

1. **Single codebase** for all server types
2. **Easy onboarding** of new servers (just set hostname)
3. **Centralized config** in one file/dict
4. **Type-safe** with proper defaults
5. **Testable** (mock device detection)

## See Also

- [SETUP.md](SETUP.md) - Deployment guide
- [STATEDIRECTORY_PATTERN.md](STATEDIRECTORY_PATTERN.md) - State management
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues
