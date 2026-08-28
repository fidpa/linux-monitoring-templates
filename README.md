# Linux Monitoring Templates

![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)
![CI](https://github.com/fidpa/linux-monitoring-templates/actions/workflows/lint.yml/badge.svg)
![Bash](https://img.shields.io/badge/Bash-4.0%2B-blue?logo=gnu-bash)
![Python](https://img.shields.io/badge/Python-3.10%2B-yellow?logo=python)
![Templates](https://img.shields.io/badge/Templates-10-orange)
![GitHub Stars](https://img.shields.io/github/stars/fidpa/linux-monitoring-templates?style=social)
![Last Commit](https://img.shields.io/github/last-commit/fidpa/linux-monitoring-templates)

**Production-ready monitoring script templates with StateDirectory pattern**

Stop reinventing the wheel. Start with battle-tested templates for system monitoring scripts with Prometheus integration, systemd best practices, and rate-limited alerting in the two generic templates.

## Features

- **StateDirectory Pattern**: Persistent state management (alerts survive restarts)
- **Smart Rate-Limiting**: Prevent alert spam with configurable cooldowns, in
  `bash/generic-monitor.sh` and `python/generic-monitor.py`
- **Prometheus Ready**: Export metrics to Prometheus textfile collector, in all
  eight templates
- **systemd Integration**: Service + timer templates with security hardening
- **Telegram Alerts**: Optional webhook notifications, in the two generic
  templates
- **Multi-Language**: Bash and Python 3.10+ templates
- **Device-Agnostic**: Adaptable for different server types via profiles
- **Zero Dependencies**: Pure Bash and Python stdlib, except
  `python/process-monitor.py`, which requires `psutil`

## Quick Start

```bash
# Clone repository
git clone https://github.com/fidpa/linux-monitoring-templates
cd linux-monitoring-templates

# Choose a template
cp bash/disk-monitor.sh /usr/local/bin/disk-monitor
chmod +x /usr/local/bin/disk-monitor

# Deploy systemd units
sudo cp systemd/monitor.service.template /etc/systemd/system/disk-monitor.service
sudo cp systemd/monitor.timer.template /etc/systemd/system/disk-monitor.timer

# Edit and replace placeholders
sudo nano /etc/systemd/system/disk-monitor.service

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable --now disk-monitor.timer
```

## Templates Overview

### Bash Templates (4)

| Template | Purpose |
|----------|---------|
| `bash/generic-monitor.sh` | Base template with all patterns |
| `bash/disk-monitor.sh` | Disk usage monitoring |
| `bash/service-health-check.sh` | systemd service status |
| `bash/network-monitor.sh` | Network connectivity (ping) |

### Python Templates (4)

| Template | Purpose |
|----------|---------|
| `python/generic-monitor.py` | Base template with all patterns |
| `python/process-monitor.py` | Process CPU/memory monitoring |
| `python/api-health-check.py` | HTTP endpoint monitoring |
| `python/database-check.py` | Database connectivity |

### systemd Templates (2)

| Template | Purpose |
|----------|---------|
| `systemd/monitor.service.template` | Service unit with StateDirectory |
| `systemd/monitor.timer.template` | Timer unit for periodic execution |

> **What the six specialized templates do and do not do.** `disk-monitor.sh`,
> `service-health-check.sh`, `network-monitor.sh`, `process-monitor.py`,
> `api-health-check.py` and `database-check.py` export Prometheus metrics and
> exit with a status code. Alerting, rate-limiting and the `last_alert_*` state
> files live in `generic-monitor.sh` and `generic-monitor.py`, which is where
> you copy them from. See [docs/SETUP.md](docs/SETUP.md).

## Key Concept: StateDirectory vs RuntimeDirectory

**The Problem**: Your alert deduplication breaks after service restart.

**Why**: You're using `RuntimeDirectory` (deleted after service ends).

**Solution**: Use `StateDirectory` (persistent across restarts).

```ini
# ❌ WRONG - State files deleted after service ends
RuntimeDirectory=my-monitor

# ✅ CORRECT - State files persist across restarts
StateDirectory=my-monitor
```

See [docs/STATEDIRECTORY_PATTERN.md](docs/STATEDIRECTORY_PATTERN.md) for full explanation.

## Installation

**Option 1: Copy-Paste**
```bash
# Copy templates to your project
cp -r linux-monitoring-templates/{bash,python,systemd} ~/my-project/
```

**Option 2: Direct Deploy**
```bash
# Deploy example stack
cd examples/complete-stack
sudo ./deploy.sh
```

## Configuration

### Environment Variables

```bash
# Service configuration
SERVICE_NAME=disk-monitor
DEVICE_NAME=$(hostname -s)

# Thresholds
WARNING_THRESHOLD=75
CRITICAL_THRESHOLD=90

# Paths (auto-configured via systemd)
STATE_DIR=/var/lib/disk-monitor
LOG_DIR=/var/log

# Prometheus textfile collector (optional).
# Metrics export is skipped silently while this directory does not exist.
METRICS_DIR=/var/lib/node_exporter/textfile_collector
```

### Telegram Alerts (Optional)

```bash
# Create secrets file
cat > ~/.env.secrets <<EOF
TELEGRAM_BOT_TOKEN=123456:ABC-DEF...
TELEGRAM_CHAT_ID=1234567890
EOF

chmod 600 ~/.env.secrets
```

### Prometheus Metrics (Optional)

```bash
# Enable textfile collector
sudo nano /etc/systemd/system/node_exporter.service

ExecStart=/usr/local/bin/node_exporter \
  --collector.textfile.directory=/var/lib/node_exporter/textfile_collector
```

## Requirements

**Minimal:**
- Bash 4.0+ (for Bash templates)
- Python 3.10+ (for Python templates)
- systemd

**Required for one template:**
- psutil (for `process-monitor.py`)

**Optional:**
- Node Exporter with textfile collector (for Prometheus)
- Telegram Bot (for alerts from the generic templates)

## Documentation

| Document | Description |
|----------|-------------|
| [SETUP.md](docs/SETUP.md) | Deployment guide |
| [STATEDIRECTORY_PATTERN.md](docs/STATEDIRECTORY_PATTERN.md) | Why StateDirectory matters |
| [PROMETHEUS_INTEGRATION.md](docs/PROMETHEUS_INTEGRATION.md) | Metrics export guide |
| [DEVICE_PROFILES.md](docs/DEVICE_PROFILES.md) | Multi-server configuration |
| [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common issues and fixes |

## Examples

Ready-to-deploy monitoring stack:
- `examples/complete-stack/` - Disk, service, network monitoring with systemd units

## Architecture Highlights

**StateDirectory Pattern:**
- Persistent state storage in `/var/lib/`
- Rate-limiting survives service restarts
- No alert spam after reboot

**Smart Alerting** (`generic-monitor.sh` and `generic-monitor.py`)**:**
- Configurable cooldown periods: `RATE_LIMIT_SECONDS` defaults to 10800 (3
  hours) in Bash, `ALERT_COOLDOWN` to 21600 (6 hours) in Python
- Deduplication via `last_alert_*` timestamp files
- Recovery alerts, switchable in Bash via `ENABLE_RECOVERY_ALERTS`

**Security Hardening:**
- NoNewPrivileges=true
- ProtectSystem=strict
- PrivateTmp=true
- Minimal ReadWritePaths

**Prometheus Integration:**
- Atomic writes (no partial metrics)
- HELP + TYPE metadata
- Status gauges (0=OK, 1=WARNING, 2=CRITICAL)

## Use Cases

**System Monitoring:**
- Disk usage alerts
- Service health checks
- Process resource monitoring
- Network connectivity

**Application Monitoring:**
- API endpoint health
- Database connectivity
- Queue length tracking
- Custom business metrics

**Infrastructure Monitoring:**
- Multi-server deployments
- Device-specific configurations
- Centralized alerting
- Prometheus dashboards

## Why These Templates?

**1. Production-Ready**
- Used in real infrastructure (not toy examples)
- Battle-tested patterns (state management, atomic metric writes)
- Security hardening built-in

**2. Incident-Driven Design**
- StateDirectory pattern learned from alert spam incident
- Atomic writes prevent partial metrics
- RemainAfterExit prevents race conditions

**3. Copy-Paste Ready**
- No framework lock-in
- Minimal dependencies
- Clear placeholder syntax
- Extensive comments

## License

MIT License - see [LICENSE](LICENSE) for details.

## Author

Marc Allgeier ([@fidpa](https://github.com/fidpa))

## Contributing

Contributions welcome! Please open an issue or pull request.

## See Also

- [bash-production-toolkit](https://github.com/fidpa/bash-production-toolkit) - Production Bash libraries
- [server-scripts-cli](https://github.com/fidpa/server-scripts-cli) - Script management CLI
