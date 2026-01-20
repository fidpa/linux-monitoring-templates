# Linux Monitoring Templates

![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)
![CI](https://github.com/fidpa/linux-monitoring-templates/actions/workflows/lint.yml/badge.svg)
![Bash](https://img.shields.io/badge/Bash-4.0%2B-blue?logo=gnu-bash)
![Python](https://img.shields.io/badge/Python-3.10%2B-yellow?logo=python)
![Templates](https://img.shields.io/badge/Templates-10-orange)
![GitHub Stars](https://img.shields.io/github/stars/fidpa/linux-monitoring-templates?style=social)
![Last Commit](https://img.shields.io/github/last-commit/fidpa/linux-monitoring-templates)

**Production-ready monitoring script templates with StateDirectory pattern**

Stop reinventing the wheel. Start with battle-tested templates for system monitoring scripts with built-in rate-limiting, Prometheus integration, and systemd best practices.

## Features

- **StateDirectory Pattern**: Persistent state management (alerts survive restarts)
- **Smart Rate-Limiting**: Prevent alert spam with configurable cooldowns
- **Prometheus Ready**: Export metrics to Prometheus textfile collector
- **systemd Integration**: Service + timer templates with security hardening
- **Telegram Alerts**: Optional webhook notifications
- **Multi-Language**: Bash and Python 3.10+ templates
- **Device-Agnostic**: Adaptable for different server types via profiles
- **Zero Dependencies**: Pure Bash/Python stdlib (optional: psutil, requests)

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

**Optional:**
- Node Exporter with textfile collector (for Prometheus)
- Telegram Bot (for alerts)
- psutil (for process-monitor.py)

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

**Smart Alerting:**
- Configurable cooldown periods (default: 3 hours)
- Deduplication via timestamp files
- Recovery alerts (optional)

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
- Battle-tested patterns (rate-limiting, state management)
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
