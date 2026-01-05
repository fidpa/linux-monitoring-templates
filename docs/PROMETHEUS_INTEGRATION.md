# Prometheus Integration

Export monitoring metrics to Prometheus Textfile Collector.

## Overview

Monitoring scripts can export metrics that Prometheus scrapes for:
- Dashboards (Grafana)
- Alerting rules
- Historical analysis
- Capacity planning

## Textfile Collector Setup

**1. Enable textfile collector on Node Exporter:**
```bash
# systemd service
sudo nano /etc/systemd/system/node_exporter.service

[Service]
ExecStart=/usr/local/bin/node_exporter \
  --collector.textfile.directory=/var/lib/node_exporter/textfile_collector
```

**2. Create collector directory:**
```bash
sudo mkdir -p /var/lib/node_exporter/textfile_collector
sudo chown node_exporter:node_exporter /var/lib/node_exporter/textfile_collector
```

**3. Restart Node Exporter:**
```bash
sudo systemctl restart node_exporter
```

## Metrics Format

Prometheus expects metrics in this format:

```
# HELP metric_name Description of the metric
# TYPE metric_name gauge
metric_name{label="value"} 42

# HELP another_metric Another description
# TYPE another_metric counter
another_metric{label="value"} 100
```

## Code Examples

### Bash Script

```bash
#!/bin/bash
set -uo pipefail

METRICS_FILE="/var/lib/node_exporter/textfile_collector/disk_monitor.prom"

# Check disk usage
usage=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
status=0
[[ $usage -ge 90 ]] && status=2
[[ $usage -ge 80 ]] && status=1

# Export metrics
cat > "$METRICS_FILE" <<EOF
# HELP disk_usage_percent Disk usage percentage
# TYPE disk_usage_percent gauge
disk_usage_percent{mount="/"} ${usage}

# HELP disk_monitor_status Monitoring status (0=OK, 1=WARNING, 2=CRITICAL)
# TYPE disk_monitor_status gauge
disk_monitor_status ${status}

# HELP disk_monitor_last_check_timestamp Last check timestamp
# TYPE disk_monitor_last_check_timestamp gauge
disk_monitor_last_check_timestamp $(date +%s)
EOF

echo "Metrics exported to $METRICS_FILE"
```

### Python Script

```python
#!/usr/bin/env python3
import time
from pathlib import Path

METRICS_FILE = Path("/var/lib/node_exporter/textfile_collector/disk_monitor.prom")

# Check disk usage
import shutil
usage = shutil.disk_usage("/")
percent = (usage.used / usage.total) * 100

status = 0
if percent >= 90:
    status = 2
elif percent >= 80:
    status = 1

# Export metrics
with open(METRICS_FILE, 'w') as f:
    f.write("# HELP disk_usage_percent Disk usage percentage\n")
    f.write("# TYPE disk_usage_percent gauge\n")
    f.write(f'disk_usage_percent{{mount="/"}} {percent:.2f}\n')
    f.write("\n")

    f.write("# HELP disk_monitor_status Monitoring status (0=OK, 1=WARNING, 2=CRITICAL)\n")
    f.write("# TYPE disk_monitor_status gauge\n")
    f.write(f"disk_monitor_status {status}\n")
    f.write("\n")

    f.write("# HELP disk_monitor_last_check_timestamp Last check timestamp\n")
    f.write("# TYPE disk_monitor_last_check_timestamp gauge\n")
    f.write(f"disk_monitor_last_check_timestamp {int(time.time())}\n")

print(f"Metrics exported to {METRICS_FILE}")
```

## Atomic Writes

**Problem**: Prometheus might read file while script is writing → incomplete metrics.

**Solution**: Write to temp file, then atomic rename.

### Bash Atomic Write

```bash
METRICS_FILE="/var/lib/node_exporter/textfile_collector/disk_monitor.prom"
TEMP_FILE="${METRICS_FILE}.$$"

# Write to temp file
cat > "$TEMP_FILE" <<EOF
# HELP disk_usage_percent Disk usage percentage
# TYPE disk_usage_percent gauge
disk_usage_percent{mount="/"} ${usage}
EOF

# Atomic rename (POSIX guarantees atomicity)
mv "$TEMP_FILE" "$METRICS_FILE"
```

### Python Atomic Write

```python
import tempfile
import os
from pathlib import Path

METRICS_FILE = Path("/var/lib/node_exporter/textfile_collector/disk_monitor.prom")

# Write to temp file in same directory (ensures same filesystem)
with tempfile.NamedTemporaryFile(
    mode='w',
    dir=METRICS_FILE.parent,
    prefix='.disk_monitor.',
    suffix='.prom.tmp',
    delete=False
) as f:
    temp_path = f.name
    f.write("# HELP disk_usage_percent Disk usage percentage\n")
    f.write("# TYPE disk_usage_percent gauge\n")
    f.write(f"disk_usage_percent{{mount=\"/\"}} {percent:.2f}\n")

# Atomic rename
os.replace(temp_path, str(METRICS_FILE))
```

## Metric Types

| Type | Description | Example |
|------|-------------|---------|
| **gauge** | Value that goes up and down | CPU usage, disk usage, temperature |
| **counter** | Value that only increases | Total requests, errors, bytes sent |
| **histogram** | Distribution of values | Request duration, response size |
| **summary** | Similar to histogram | Quantiles, percentiles |

For monitoring scripts, **gauge** is most common.

## Labels

Use labels to add dimensions to metrics:

```
disk_usage_percent{mount="/",device="sda1"} 85
disk_usage_percent{mount="/home",device="sda2"} 42
```

**Best practices**:
- Use consistent label names
- Don't use too many labels (cardinality explosion)
- Prefer static labels (not dynamic values like timestamps)

## Prometheus Queries

**Check metric availability:**
```promql
disk_usage_percent
```

**Alert on high disk usage:**
```promql
disk_usage_percent{mount="/"} > 90
```

**Rate of change:**
```promql
rate(disk_usage_percent[5m])
```

## Grafana Dashboard

**Panel 1: Disk Usage Gauge**
```promql
disk_usage_percent{mount="/"}
```

**Panel 2: Monitoring Status**
```promql
disk_monitor_status
```

**Panel 3: Last Check Time**
```promql
(time() - disk_monitor_last_check_timestamp) / 60
```

## Troubleshooting

**Metrics not appearing in Prometheus:**
```bash
# Check if file exists
ls -la /var/lib/node_exporter/textfile_collector/disk_monitor.prom

# Check file permissions
sudo chmod 644 /var/lib/node_exporter/textfile_collector/disk_monitor.prom

# Check Node Exporter logs
journalctl -u node_exporter --since "10 minutes ago"

# Test scrape endpoint
curl http://localhost:9100/metrics | grep disk_usage
```

**Stale metrics:**
```bash
# Add timestamp metric to detect stale data
disk_monitor_last_check_timestamp $(date +%s)
```

**Prometheus query:**
```promql
# Alert if metrics older than 10 minutes
(time() - disk_monitor_last_check_timestamp) > 600
```

## See Also

- [STATEDIRECTORY_PATTERN.md](STATEDIRECTORY_PATTERN.md) - State management
- [SETUP.md](SETUP.md) - Deployment guide
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues
