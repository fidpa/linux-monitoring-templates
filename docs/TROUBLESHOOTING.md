# Troubleshooting

Common issues and solutions for monitoring templates.

## Service Won't Start

**Symptom:**
```bash
sudo systemctl start disk-monitor.service
# Job for disk-monitor.service failed because the control process exited with error code.
```

**Solutions:**

**1. Check service status:**
```bash
sudo systemctl status disk-monitor.service
# Look for exit code and error message
```

**2. Check logs:**
```bash
journalctl -xe -u disk-monitor.service
# Look for ERROR or CRITICAL messages
```

**3. Verify script path:**
```bash
# Check if script exists
ls -la /usr/local/bin/disk-monitor

# Test execution
sudo -u monitoring /usr/local/bin/disk-monitor
```

**4. Check permissions:**
```bash
# Script must be executable
sudo chmod +x /usr/local/bin/disk-monitor

# Service user must have permissions
sudo chown monitoring:monitoring /usr/local/bin/disk-monitor
```

## Rate-Limiting Doesn't Work

**Symptom:** Alerts sent on every service run, ignoring cooldown.

**Cause:** Using `RuntimeDirectory` instead of `StateDirectory`.

**Solution:**
```ini
# Check service file
sudo nano /etc/systemd/system/disk-monitor.service

# ❌ WRONG
RuntimeDirectory=disk-monitor

# ✅ CORRECT
StateDirectory=disk-monitor
```

See [STATEDIRECTORY_PATTERN.md](STATEDIRECTORY_PATTERN.md) for details.

## Permission Denied Errors

**Symptom:**
```
ERROR: Permission denied: '/var/lib/disk-monitor/last_alert_CRITICAL'
```

**Solutions:**

**1. Check StateDirectory ownership:**
```bash
ls -la /var/lib/disk-monitor/
# Should show: drwxr-x--- monitoring monitoring

# Fix ownership
sudo chown -R monitoring:monitoring /var/lib/disk-monitor/
```

**2. Check StateDirectoryMode:**
```bash
# Edit service file
sudo nano /etc/systemd/system/disk-monitor.service

# Should have:
StateDirectoryMode=0750

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart disk-monitor.service
```

**3. Check ReadWritePaths:**
```bash
# Edit service file
ReadWritePaths=/var/log /var/lib/node_exporter/textfile_collector

# Add any missing paths
```

## Telegram Alerts Not Sent

**Symptom:** Script runs successfully but no Telegram messages.

**Solutions:**

**1. Check secrets file:**
```bash
cat ~/.env.secrets
# Should contain:
# TELEGRAM_BOT_TOKEN=123456:ABC-DEF...
# TELEGRAM_CHAT_ID=1234567890

# Check permissions
ls -la ~/.env.secrets
# Should be: -rw------- (600)
```

**2. Test Telegram API:**
```bash
curl -X POST "https://api.telegram.org/bot<TOKEN>/sendMessage" \
  -d "chat_id=<CHAT_ID>" \
  -d "text=Test message"

# Should return: {"ok":true,...}
```

**3. Check rate-limiting:**
```bash
# Check if alert was rate-limited
journalctl -u disk-monitor.service | grep "Rate limited"

# Reset rate-limiting state
sudo rm /var/lib/disk-monitor/last_alert_*
```

**4. Check network connectivity:**
```bash
# Test internet connection
ping -c 3 api.telegram.org

# Test HTTPS
curl -I https://api.telegram.org
```

## Prometheus Metrics Not Showing

**Symptom:** Metrics not visible in Prometheus.

**Solutions:**

**1. Check metrics file:**
```bash
# Check if file exists
ls -la /var/lib/node_exporter/textfile_collector/disk_monitor.prom

# Check file contents
cat /var/lib/node_exporter/textfile_collector/disk_monitor.prom
```

**2. Check file permissions:**
```bash
# File must be readable by node_exporter
sudo chmod 644 /var/lib/node_exporter/textfile_collector/disk_monitor.prom
```

**3. Check Node Exporter config:**
```bash
# Verify textfile collector is enabled
systemctl status node_exporter | grep textfile

# Should show: --collector.textfile.directory=...
```

**4. Test scrape endpoint:**
```bash
curl http://localhost:9100/metrics | grep disk_monitor

# If no output, metrics not exported
```

**5. Check Prometheus config:**
```yaml
# /etc/prometheus/prometheus.yml
scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
```

## Service Shows "inactive" Instead of "active (exited)"

**Symptom:**
```bash
sudo systemctl status disk-monitor.service
# Active: inactive (dead)
```

**Cause:** Missing `RemainAfterExit=yes` for oneshot services.

**Solution:**
```ini
# Edit service file
sudo nano /etc/systemd/system/disk-monitor.service

# Add:
[Service]
Type=oneshot
RemainAfterExit=yes

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart disk-monitor.service
```

## Python Script Fails with ImportError

**Symptom:**
```
ImportError: No module named 'psutil'
```

**Solutions:**

**1. Install missing packages:**
```bash
# For process-monitor.py
sudo pip3 install psutil

# For database-check.py
sudo pip3 install psycopg2-binary  # PostgreSQL
sudo pip3 install mysql-connector-python  # MySQL
```

**2. Use virtual environment:**
```bash
# Create venv
python3 -m venv /opt/monitoring/venv

# Install packages
/opt/monitoring/venv/bin/pip install psutil

# Update service file
ExecStart=/opt/monitoring/venv/bin/python3 /usr/local/bin/process-monitor.py
```

## Timer Not Triggering

**Symptom:** Timer is active but service never runs.

**Solutions:**

**1. Check timer status:**
```bash
systemctl status disk-monitor.timer
# Should show: "Next elapse: ..."

# List all timers
systemctl list-timers --all | grep disk-monitor
```

**2. Check timer config:**
```bash
sudo nano /etc/systemd/system/disk-monitor.timer

# Verify OnCalendar is set
OnCalendar=*:0/30  # Every 30 minutes
```

**3. Manually trigger:**
```bash
sudo systemctl start disk-monitor.service
# Check if service runs successfully

# Check logs
journalctl -u disk-monitor.service --since "1 minute ago"
```

**4. Reload systemd:**
```bash
sudo systemctl daemon-reload
sudo systemctl restart disk-monitor.timer
```

## StateDirectory Not Created

**Symptom:**
```bash
ls -la /var/lib/disk-monitor/
# ls: cannot access '/var/lib/disk-monitor/': No such file or directory
```

**Solutions:**

**1. Check StateDirectory config:**
```bash
sudo nano /etc/systemd/system/disk-monitor.service

# Must have:
StateDirectory=disk-monitor
```

**2. Start service:**
```bash
# StateDirectory is created on service start
sudo systemctl start disk-monitor.service

# Check again
ls -la /var/lib/disk-monitor/
```

**3. Manual creation (for testing):**
```bash
sudo mkdir -p /var/lib/disk-monitor
sudo chown monitoring:monitoring /var/lib/disk-monitor
sudo chmod 750 /var/lib/disk-monitor
```

## Logs Not Written

**Symptom:** No log file in `/var/log/`.

**Solutions:**

**1. Check log directory permissions:**
```bash
ls -ld /var/log
# Should be: drwxrwxr-x root syslog

# Check if service user can write
sudo -u monitoring touch /var/log/test.log
```

**2. Check ReadWritePaths:**
```bash
# Edit service file
sudo nano /etc/systemd/system/disk-monitor.service

# Must include:
ReadWritePaths=/var/log
```

**3. Check script logging config:**
```python
# Python
LOG_FILE = Path("/var/log/disk-monitor.log")
LOG_FILE.parent.mkdir(parents=True, exist_ok=True)  # Create parent dir

# Bash
LOG_DIR="/var/log"
mkdir -p "$LOG_DIR"
```

## High Memory/CPU Usage

**Symptom:** Monitoring script uses excessive resources.

**Solutions:**

**1. Add resource limits:**
```ini
# Edit service file
[Service]
MemoryMax=256M
CPUQuota=25%
TasksMax=10
```

**2. Reduce check frequency:**
```ini
# Edit timer file
# Change from every 5 minutes to every 15 minutes
OnCalendar=*:0/15
```

**3. Optimize script:**
```bash
# Bash: Avoid subshells in loops
# ❌ WRONG
for file in *.txt; do
    cat "$file" | grep pattern
done

# ✅ CORRECT
for file in *.txt; do
    grep pattern "$file"
done
```

## Get Help

**1. Check logs first:**
```bash
journalctl -u disk-monitor.service --since "1 hour ago" --no-pager
```

**2. Enable debug logging:**
```bash
# Python
logger.setLevel(logging.DEBUG)

# Bash
set -x  # Enable debug mode
```

**3. Test in isolation:**
```bash
# Run script manually
sudo -u monitoring /usr/local/bin/disk-monitor

# Check exit code
echo $?
```

**4. Report issue:**
- Include error message
- Include systemd service/timer files
- Include relevant log excerpts
- Describe expected vs actual behavior

## See Also

- [SETUP.md](SETUP.md) - Deployment guide
- [STATEDIRECTORY_PATTERN.md](STATEDIRECTORY_PATTERN.md) - State management
- [PROMETHEUS_INTEGRATION.md](PROMETHEUS_INTEGRATION.md) - Metrics export
