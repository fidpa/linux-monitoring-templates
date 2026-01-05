# systemd Templates

Production-ready systemd unit templates for monitoring scripts.

## Templates

| File | Purpose |
|------|---------|
| `monitor.service.template` | Service unit with StateDirectory pattern |
| `monitor.timer.template` | Timer unit for periodic execution |

## Quick Start

**1. Copy templates:**
```bash
sudo cp monitor.service.template /etc/systemd/system/disk-monitor.service
sudo cp monitor.timer.template /etc/systemd/system/disk-monitor.timer
```

**2. Replace placeholders:**
```bash
# Edit service file
sudo nano /etc/systemd/system/disk-monitor.service

# Replace:
# {{SERVICE_NAME}} → "Disk Usage Monitor"
# {{service_name}} → disk-monitor
# {{EXEC_PATH}} → /usr/local/bin/disk-monitor.sh
# {{SERVICE_USER}} → monitoring
# {{SERVICE_GROUP}} → monitoring
```

**3. Enable and start:**
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now disk-monitor.timer
sudo systemctl status disk-monitor.timer
```

## Placeholder Reference

### Service Template

| Placeholder | Example | Description |
|-------------|---------|-------------|
| `{{SERVICE_NAME}}` | "Disk Monitor" | Human-readable name |
| `{{service_name}}` | disk-monitor | systemd identifier |
| `{{EXEC_PATH}}` | /usr/local/bin/disk-monitor.sh | Script path |
| `{{SERVICE_USER}}` | monitoring | User to run as |
| `{{SERVICE_GROUP}}` | monitoring | Group to run as |
| `{{WORKING_DIR}}` | /opt/monitoring | Working directory (optional) |
| `{{DOC_URL}}` | https://... | Documentation URL (optional) |

### Timer Template

| Placeholder | Example | Description |
|-------------|---------|-------------|
| `{{SERVICE_NAME}}` | "Disk Monitor" | Human-readable name |
| `{{service_name}}` | disk-monitor | systemd identifier |
| `{{TIMER_SCHEDULE}}` | *:0/30 | OnCalendar schedule |
| `{{RANDOMIZED_DELAY}}` | 60 | Random delay (0-N seconds) |

## StateDirectory Pattern

**CRITICAL**: Always use `StateDirectory` for persistent state (not `RuntimeDirectory`!).

```ini
# ✅ CORRECT - Persistent state
StateDirectory=disk-monitor
# → Creates /var/lib/disk-monitor/ (survives restarts)

# ❌ WRONG - Ephemeral state
RuntimeDirectory=disk-monitor
# → Creates /run/disk-monitor/ (deleted after service ends)
```

**Why this matters**:
- Rate-limiting timestamps must persist across restarts
- StateDirectory = persistent storage
- RuntimeDirectory = temporary storage (tmpfs)

See: [STATEDIRECTORY_PATTERN.md](../docs/STATEDIRECTORY_PATTERN.md)

## Common Schedules

```ini
# Every 15 minutes
OnCalendar=*:0/15

# Every 30 minutes
OnCalendar=*:0/30

# Every hour
OnCalendar=hourly

# Daily at 04:00
OnCalendar=*-*-* 04:00

# Weekly on Monday at 09:00
OnCalendar=Mon *-*-* 09:00

# Multiple schedules (runs at both times)
OnCalendar=*-*-* 04:00
OnCalendar=*-*-* 16:00
```

## Verification

**Check service status:**
```bash
systemctl status disk-monitor.service
systemctl status disk-monitor.timer
```

**Check StateDirectory:**
```bash
ls -la /var/lib/disk-monitor/
# Should show: last_alert_* files
```

**Check logs:**
```bash
journalctl -u disk-monitor.service --since "1 hour ago"
```

**Manual trigger:**
```bash
sudo systemctl start disk-monitor.service
```

## Troubleshooting

**Service fails with "Permission denied":**
- Check User/Group ownership
- Verify ReadWritePaths includes all write targets

**Rate-limiting doesn't work:**
- Check StateDirectory (not RuntimeDirectory!)
- Verify RemainAfterExit=yes

**Service shows "inactive" instead of "active (exited)":**
- Add RemainAfterExit=yes

See: [TROUBLESHOOTING.md](../docs/TROUBLESHOOTING.md)
