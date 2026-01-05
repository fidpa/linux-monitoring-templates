# StateDirectory Pattern for Monitoring Scripts

**Problem**: Why does my alert deduplication break after service restarts?

**Solution**: Use `StateDirectory` (persistent) instead of `RuntimeDirectory` (ephemeral).

## The Problem

Monitoring scripts need to track state across service restarts for:
- **Rate-limiting**: Prevent alert spam (e.g., don't send same alert every 5 minutes)
- **Deduplication**: Track which alerts were already sent
- **Recovery detection**: Know when issues are resolved

If your state files disappear after service restart, rate-limiting breaks → alert spam.

## Wrong Pattern: RuntimeDirectory

```ini
[Service]
RuntimeDirectory=my-monitor
# → Creates /run/my-monitor/ (tmpfs, ephemeral)
```

**What happens**:
1. Service starts → `/run/my-monitor/` created
2. Script writes `last_alert_CRITICAL` timestamp
3. Service ends → `/run/my-monitor/` **DELETED** (tmpfs cleanup)
4. Service restarts → State files **GONE**
5. Script can't check last alert time → Sends duplicate alert

**Result**: Alert spam on every service restart.

## Correct Pattern: StateDirectory

```ini
[Service]
StateDirectory=my-monitor
# → Creates /var/lib/my-monitor/ (persistent)
```

**What happens**:
1. Service starts → `/var/lib/my-monitor/` created
2. Script writes `last_alert_CRITICAL` timestamp
3. Service ends → `/var/lib/my-monitor/` **PERSISTS**
4. Service restarts → State files **STILL THERE**
5. Script reads last alert time → Skips duplicate alert (rate-limited)

**Result**: Rate-limiting works as expected.

## Code Examples

### systemd Service Unit

```ini
[Unit]
Description=Disk Usage Monitor
After=network-online.target

[Service]
Type=oneshot
User=monitoring
Group=monitoring

# CRITICAL: Use StateDirectory for persistent state
StateDirectory=disk-monitor
StateDirectoryMode=0750

# Script path
ExecStart=/usr/local/bin/disk-monitor.sh

# MANDATORY for StateDirectory
RemainAfterExit=yes

# Allow writes to logs and metrics
ReadWritePaths=/var/log /var/lib/node_exporter/textfile_collector

[Install]
WantedBy=multi-user.target
```

### Bash Script

```bash
#!/bin/bash
set -uo pipefail

# Use StateDirectory (persistent)
STATE_DIR="${STATE_DIRECTORY:-/var/lib/disk-monitor}"

should_send_alert() {
    local alert_type="$1"
    local alert_file="${STATE_DIR}/last_alert_${alert_type}"
    local current_time=$(date +%s)
    local cooldown=10800  # 3 hours

    if [[ -f "$alert_file" ]]; then
        local last_alert=$(cat "$alert_file")
        local time_diff=$((current_time - last_alert))

        if (( time_diff < cooldown )); then
            echo "Rate limited (sent ${time_diff}s ago)" >&2
            return 1
        fi
    fi

    return 0
}

record_alert() {
    local alert_type="$1"
    echo "$(date +%s)" > "${STATE_DIR}/last_alert_${alert_type}"
}

# Check disk usage
usage=$(df / | awk 'NR==2 {print $5}' | tr -d '%')

if (( usage > 90 )); then
    if should_send_alert "CRITICAL"; then
        send_telegram_alert "Disk full: ${usage}%"
        record_alert "CRITICAL"
    fi
fi
```

### Python Script

```python
#!/usr/bin/env python3
import os
import time
from pathlib import Path

# Use StateDirectory (persistent)
STATE_DIR = Path(os.getenv("STATE_DIRECTORY", "/var/lib/disk-monitor"))
STATE_DIR.mkdir(parents=True, exist_ok=True)

ALERT_COOLDOWN = 10800  # 3 hours

def should_send_alert(alert_type: str) -> bool:
    """Check if alert should be sent (rate-limiting)."""
    alert_file = STATE_DIR / f"last_alert_{alert_type}"
    current_time = int(time.time())

    if alert_file.exists():
        last_alert = int(alert_file.read_text().strip())
        time_diff = current_time - last_alert

        if time_diff < ALERT_COOLDOWN:
            print(f"Rate limited (sent {time_diff}s ago)")
            return False

    return True

def record_alert(alert_type: str) -> None:
    """Record alert timestamp for rate-limiting."""
    alert_file = STATE_DIR / f"last_alert_{alert_type}"
    alert_file.write_text(str(int(time.time())))

# Check disk usage
import shutil
usage = shutil.disk_usage("/")
percent = (usage.used / usage.total) * 100

if percent > 90:
    if should_send_alert("CRITICAL"):
        send_telegram_alert(f"Disk full: {percent:.1f}%")
        record_alert("CRITICAL")
```

## Environment Variable Detection

**systemd automatically sets `STATE_DIRECTORY`** when using `StateDirectory=`:

```bash
# Bash
STATE_DIR="${STATE_DIRECTORY:-/var/lib/my-monitor}"

# Python
STATE_DIR = Path(os.getenv("STATE_DIRECTORY", "/var/lib/my-monitor"))
```

This makes scripts portable:
- Run via systemd → Uses `/var/lib/my-monitor/`
- Run manually → Uses fallback path

## Verification

**Check if StateDirectory was created:**
```bash
sudo systemctl start disk-monitor.service
ls -la /var/lib/disk-monitor/
# Should show: drwxr-x--- monitoring monitoring
```

**Check if state persists after restart:**
```bash
# First run (creates state files)
sudo systemctl start disk-monitor.service
ls /var/lib/disk-monitor/
# Output: last_alert_CRITICAL

# Restart service
sudo systemctl restart disk-monitor.service
ls /var/lib/disk-monitor/
# Output: last_alert_CRITICAL (still there!)
```

**Test rate-limiting:**
```bash
# Trigger alert
sudo systemctl start disk-monitor.service
# Alert sent

# Trigger again immediately
sudo systemctl start disk-monitor.service
# Alert skipped (rate-limited)
```

## Common Mistakes

**1. Using RuntimeDirectory for state files**
```ini
# ❌ WRONG
RuntimeDirectory=my-monitor
# State files deleted after service ends
```

**2. Forgetting RemainAfterExit=yes**
```ini
# ❌ WRONG (without RemainAfterExit)
Type=oneshot
StateDirectory=my-monitor
# May cause race conditions with StateDirectory
```

**3. Wrong permissions**
```ini
# ❌ WRONG (too permissive)
StateDirectoryMode=0777

# ✅ CORRECT
StateDirectoryMode=0750  # Owner: rwx, Group: r-x
```

**4. Hardcoded paths instead of $STATE_DIRECTORY**
```bash
# ❌ WRONG
STATE_DIR="/var/lib/my-monitor"

# ✅ CORRECT
STATE_DIR="${STATE_DIRECTORY:-/var/lib/my-monitor}"
```

## Key Takeaways

- ✅ **StateDirectory** = persistent storage (`/var/lib/`)
- ❌ **RuntimeDirectory** = temporary storage (`/run/`)
- ✅ Use `StateDirectory` for rate-limiting timestamps
- ✅ Add `RemainAfterExit=yes` for oneshot services
- ✅ Use `$STATE_DIRECTORY` environment variable in scripts
- ✅ Set `StateDirectoryMode=0750` for security

## See Also

- [PROMETHEUS_INTEGRATION.md](PROMETHEUS_INTEGRATION.md) - Metrics export
- [SETUP.md](SETUP.md) - Deployment guide
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues
