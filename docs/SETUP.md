# Setup Guide

Deploy production-ready monitoring scripts with systemd integration.

## Prerequisites

**Required:**
- Bash 4.0+ (for Bash templates)
- Python 3.10+ (for Python templates)
- systemd (for service/timer units)
- Linux system with `/var/lib/` and `/var/log/` directories

**Optional:**
- Node Exporter with textfile collector (for Prometheus metrics)
- Telegram Bot (for alerts)
- `psutil` Python package (for process-monitor.py)

## Quick Start (5 minutes)

**1. Clone repository:**
```bash
git clone https://github.com/fidpa/linux-monitoring-templates
cd linux-monitoring-templates
```

**2. Choose a template:**
```bash
# Bash example: disk monitor
cp bash/disk-monitor.sh /usr/local/bin/disk-monitor

# Python example: process monitor
cp python/process-monitor.py /usr/local/bin/process-monitor

# Make executable
sudo chmod +x /usr/local/bin/disk-monitor
sudo chmod +x /usr/local/bin/process-monitor
```

**3. Create systemd units:**
```bash
# Service
sudo cp systemd/monitor.service.template /etc/systemd/system/disk-monitor.service
sudo nano /etc/systemd/system/disk-monitor.service
# Replace placeholders (see below)

# Timer
sudo cp systemd/monitor.timer.template /etc/systemd/system/disk-monitor.timer
sudo nano /etc/systemd/system/disk-monitor.timer
# Replace placeholders (see below)
```

**4. Enable and start:**
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now disk-monitor.timer
sudo systemctl status disk-monitor.timer
```

## Placeholder Replacement

### Service Unit

Edit `/etc/systemd/system/disk-monitor.service`:

```ini
# BEFORE (template)
Description={{SERVICE_NAME}}
ExecStart={{EXEC_PATH}}
User={{SERVICE_USER}}
StateDirectory={{service_name}}

# AFTER (example)
Description=Disk Usage Monitor
ExecStart=/usr/local/bin/disk-monitor
User=monitoring
StateDirectory=disk-monitor
```

### Timer Unit

Edit `/etc/systemd/system/disk-monitor.timer`:

```ini
# BEFORE (template)
Description={{SERVICE_NAME}} Timer
OnCalendar={{TIMER_SCHEDULE}}

# AFTER (example)
Description=Disk Usage Monitor Timer
OnCalendar=*:0/30  # Every 30 minutes
```

## User and Group Setup

**Create monitoring user (recommended):**
```bash
sudo useradd -r -s /bin/false -d /var/lib/monitoring monitoring
sudo mkdir -p /var/lib/monitoring
sudo chown monitoring:monitoring /var/lib/monitoring
```

**Or use existing user:**
```bash
# Use current user
User=$(whoami)
Group=$(id -gn)

# Update service file
User=youruser
Group=yourgroup
```

## Directory Permissions

**Create required directories:**
```bash
# State directory (StateDirectory creates this automatically)
# But can pre-create for testing:
sudo mkdir -p /var/lib/disk-monitor
sudo chown monitoring:monitoring /var/lib/disk-monitor
sudo chmod 750 /var/lib/disk-monitor

# Log directory
sudo mkdir -p /var/log
sudo chmod 755 /var/log

# Metrics directory (if using Prometheus)
sudo mkdir -p /var/lib/node_exporter/textfile_collector
sudo chown node_exporter:node_exporter /var/lib/node_exporter/textfile_collector
```

## Telegram Alerts (Optional)

**1. Create Telegram Bot:**
- Message [@BotFather](https://t.me/BotFather) on Telegram
- Send `/newbot` and follow instructions
- Copy the bot token (e.g., `123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11`)

**2. Get Chat ID:**
```bash
# Send a message to your bot first
# Then run:
curl https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates

# Look for "chat":{"id":1234567890}
```

**3. Create secrets file:**
```bash
# Create secrets file
sudo nano ~/.env.secrets

# Add credentials
TELEGRAM_BOT_TOKEN=123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11
TELEGRAM_CHAT_ID=1234567890
```

**4. Secure secrets file:**
```bash
chmod 600 ~/.env.secrets
```

**5. Update script to load secrets:**
```python
# Python
SECRETS_FILE = Path(os.path.expanduser("~/.env.secrets"))

# Bash
SECRETS_FILE="${HOME}/.env.secrets"
```

## Prometheus Metrics (Optional)

**1. Install Node Exporter:**
```bash
# Download latest release
wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
tar xvfz node_exporter-*.tar.gz
sudo cp node_exporter-*/node_exporter /usr/local/bin/
```

**2. Enable textfile collector:**
```bash
sudo nano /etc/systemd/system/node_exporter.service

[Service]
ExecStart=/usr/local/bin/node_exporter \
  --collector.textfile.directory=/var/lib/node_exporter/textfile_collector
```

**3. Create collector directory:**
```bash
sudo mkdir -p /var/lib/node_exporter/textfile_collector
sudo chown node_exporter:node_exporter /var/lib/node_exporter/textfile_collector
```

**4. Restart Node Exporter:**
```bash
sudo systemctl restart node_exporter
```

**5. Verify metrics:**
```bash
curl http://localhost:9100/metrics | grep disk_monitor
```

## Testing

**1. Test script manually:**
```bash
# Bash
sudo -u monitoring /usr/local/bin/disk-monitor

# Python
sudo -u monitoring /usr/local/bin/process-monitor
```

**2. Test systemd service:**
```bash
sudo systemctl start disk-monitor.service
sudo systemctl status disk-monitor.service
```

**3. Check logs:**
```bash
journalctl -u disk-monitor.service --since "5 minutes ago"
```

**4. Check StateDirectory:**
```bash
ls -la /var/lib/disk-monitor/
# Should show: last_alert_* files
```

**5. Test rate-limiting:**
```bash
# First run (alert sent)
sudo systemctl start disk-monitor.service

# Second run (alert skipped - rate-limited)
sudo systemctl start disk-monitor.service
```

## Troubleshooting

**Service fails to start:**
```bash
# Check service status
sudo systemctl status disk-monitor.service

# Check detailed logs
journalctl -xe -u disk-monitor.service
```

**Permission denied errors:**
```bash
# Check script permissions
ls -la /usr/local/bin/disk-monitor

# Check StateDirectory ownership
ls -la /var/lib/disk-monitor/

# Fix ownership
sudo chown monitoring:monitoring /var/lib/disk-monitor/
```

**Alerts not sent:**
```bash
# Check Telegram credentials
cat ~/.env.secrets

# Test Telegram API
curl -X POST "https://api.telegram.org/bot<TOKEN>/sendMessage" \
  -d "chat_id=<CHAT_ID>" \
  -d "text=Test message"
```

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for more issues.

## Next Steps

- [STATEDIRECTORY_PATTERN.md](STATEDIRECTORY_PATTERN.md) - Understand persistent state
- [PROMETHEUS_INTEGRATION.md](PROMETHEUS_INTEGRATION.md) - Export metrics
- [DEVICE_PROFILES.md](DEVICE_PROFILES.md) - Multi-server setups
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues
