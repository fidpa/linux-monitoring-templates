# Linux Monitoring Templates

![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)
![CI](https://github.com/fidpa/linux-monitoring-templates/actions/workflows/lint.yml/badge.svg)
![Bash](https://img.shields.io/badge/Bash-4.0%2B-blue?logo=gnu-bash)
![Python](https://img.shields.io/badge/Python-3.10%2B-yellow?logo=python)
![Templates](https://img.shields.io/badge/Templates-10-orange)
![GitHub Stars](https://img.shields.io/github/stars/fidpa/linux-monitoring-templates?style=social)
![Last Commit](https://img.shields.io/github/last-commit/fidpa/linux-monitoring-templates)

**Monitoring script templates built around the systemd StateDirectory pattern**

Eight monitoring scripts and two systemd unit templates to copy into your own
project. They export Prometheus metrics, run as hardened oneshot services under
a timer, and keep their alert state in `/var/lib/` so rate-limiting survives a
restart. That last point is what the repository is about: a monitor that stores
its deduplication timestamps in `RuntimeDirectory` re-alerts on every run after
a reboot.

The badge counts 10 templates: the eight scripts under `bash/` and `python/`
plus the two unit files under `systemd/`.

## What these templates are and are not

- **Starting points, not a framework.** You copy a file, replace the
  placeholders and own the result. There is nothing to install and no version
  to track once the copy is made.
- **Two of the eight scripts alert.** `bash/generic-monitor.sh` and
  `python/generic-monitor.py` carry Telegram alerting, rate-limiting and the
  `last_alert_*` state files. The six specialized scripts export metrics and
  exit with a status code; nothing else. See the table below.
- **Linted, not tested.** CI runs ShellCheck (`--severity=error`) on `bash/`
  and `examples/`, and Ruff on `python/`. There is no test suite, and no
  automated check ever deploys a unit file: the systemd behaviour is verified
  by hand against the checklist at the end of
  `systemd/monitor.service.template`.
- **Device profiles are a recipe, not code.** No script reads a profile;
  [docs/DEVICE_PROFILES.md](docs/DEVICE_PROFILES.md) shows the hostname-to-config
  pattern you would add yourself.
- **Not a monitoring system.** No aggregation, no dashboards, no alert routing.
  The scripts write a `.prom` file for a Prometheus textfile collector, and
  what happens after the scrape is your stack's business.

## Features

- **StateDirectory pattern**: alert deduplication in `/var/lib/`, so a restart
  does not reset the cooldown
- **Rate-limiting**: `RATE_LIMIT_SECONDS` (Bash, default 10800) and
  `ALERT_COOLDOWN` (Python, default 21600) in the two generic templates
- **Prometheus export**: all eight scripts write to the textfile collector
  directory, atomically (`mv -f` in Bash, `os.replace()` in Python) so a scrape
  never catches a half-written file
- **Optional by default**: no metrics directory, no export. Every script tests
  the directory and returns early instead of failing
  (`grep -c 'METRICS_DIR' bash/*.sh python/*.py`)
- **systemd integration**: `Type=oneshot` service and timer templates with
  `StateDirectory`, `NoNewPrivileges=true`, `ProtectSystem=strict`,
  `PrivateTmp=true` and `ReadWritePaths=/var/log /var/lib/node_exporter/textfile_collector`
- **Telegram alerts**: optional, in the two generic templates, credentials read
  from a secrets file outside the repository
- **Bash and Python**: same patterns in both languages, pick per script
- **Standard library only**, with one exception: `python/process-monitor.py`
  needs `psutil`

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

# Replace the {{placeholders}} in both files
sudo nano /etc/systemd/system/disk-monitor.service

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable --now disk-monitor.timer
```

## Templates Overview

### Bash Templates (4)

| Template | Purpose | Alerting |
|----------|---------|----------|
| `bash/generic-monitor.sh` | Base template with all patterns | yes |
| `bash/disk-monitor.sh` | Disk usage of one mount point | no |
| `bash/service-health-check.sh` | systemd service status | no |
| `bash/network-monitor.sh` | Network connectivity (ping) | no |

### Python Templates (4)

| Template | Purpose | Alerting |
|----------|---------|----------|
| `python/generic-monitor.py` | Base template with all patterns | yes |
| `python/process-monitor.py` | Process CPU/memory monitoring (needs `psutil`) | no |
| `python/api-health-check.py` | HTTP endpoint monitoring | no |
| `python/database-check.py` | Database connectivity | no |

### systemd Templates (2)

| Template | Purpose |
|----------|---------|
| `systemd/monitor.service.template` | Service unit with StateDirectory |
| `systemd/monitor.timer.template` | Timer unit for periodic execution |

The six templates marked "no" export Prometheus metrics and exit with a status
code. To add alerting to one of them, copy the `send_telegram_alert` and
`should_send_alert` functions from the matching generic template;
`bash/disk-monitor.sh` marks the spot with a comment in its check function. See [docs/SETUP.md](docs/SETUP.md).

## Key Concept: StateDirectory vs RuntimeDirectory

Alert deduplication needs a timestamp that outlives the process. With
`Type=oneshot` the process ends after every check, and `RuntimeDirectory` is
cleaned up with it: the directory lives in tmpfs and is gone after the service
stops, so the next run finds no timestamp and alerts again. On a machine with a
timer every 15 minutes, that turns one problem into a message every 15 minutes.

`StateDirectory` puts the same directory in `/var/lib/`, where it survives both
the service exit and a reboot.

```ini
# WRONG - state files deleted after the service ends
RuntimeDirectory=my-monitor

# CORRECT - state files persist across restarts
StateDirectory=my-monitor
StateDirectoryMode=0750
```

The service template also sets `RemainAfterExit=yes`, which keeps the unit in
`active (exited)` and the StateDirectory in place for the whole service
lifecycle. See [docs/STATEDIRECTORY_PATTERN.md](docs/STATEDIRECTORY_PATTERN.md).

## Installation

**Option 1: Copy-Paste**
```bash
# Copy templates to your project
cp -r linux-monitoring-templates/{bash,python,systemd} ~/my-project/
```

**Option 2: Deploy the example stack**
```bash
# Disk, service and network monitor, wired to systemd units
cd examples/complete-stack
sudo ./deploy.sh          # ./deploy.sh --dry-run to see what it would do
```

The stack reads the scripts from the repository's `bash/` directory, so it
needs a full checkout rather than the `examples/` directory alone.

## Configuration

Every setting is an environment variable with a default in the script. The
service unit passes them through `Environment=` lines.

### Common to every template

| Variable | Default | Description |
|----------|---------|-------------|
| `SERVICE_NAME` | per template (`disk-monitor`, `api-health`, ...) | Used for the log file, the state directory and the metric prefix |
| `DEVICE_NAME` | `hostname -s` (Bash), `socket.gethostname()` up to the first dot (Python) | Shown in alerts, not in metrics |
| `STATE_DIR` | `/var/lib/${SERVICE_NAME}` | Set by `StateDirectory=` in the unit |
| `LOG_DIR` | `/var/log` | Log file is `${LOG_DIR}/${SERVICE_NAME}.log` |
| `METRICS_DIR` | `/var/lib/node_exporter/textfile_collector` | Export is skipped while this directory does not exist |

The three specialized Python scripts do not use `STATE_DIR`; they keep no state
between runs.

### Generic templates only

| Variable | Default | Template | Description |
|----------|---------|----------|-------------|
| `RATE_LIMIT_SECONDS` | `10800` | Bash | Cooldown between alerts of the same level |
| `ALERT_COOLDOWN` | `21600` | Python | Same, in the Python template |
| `ENABLE_RECOVERY_ALERTS` | `true` | Bash | Send a message when the state returns to OK |
| `RECOVERY_THRESHOLD` | `50` | Python | Value below which the state counts as recovered |
| `WARNING_THRESHOLD` | `75` | Python | Threshold for status 1 |
| `CRITICAL_THRESHOLD` | `90` | Python | Threshold for status 2 |
| `REBOOT_GRACE_PERIOD` | `300` | Python | Suppress alerts while uptime is below this |
| `SECRETS_FILE` | `~/.env.secrets` | both | Where the Telegram credentials are read from |
| `LOCK_DIR` | `/run` | Bash | Lock file is `${LOCK_DIR}/${SERVICE_NAME}.lock` |

### Specialized templates

| Template | Variables |
|----------|-----------|
| `bash/disk-monitor.sh` | `MOUNT_POINT` (`/`), `WARNING_THRESHOLD` (`80`), `CRITICAL_THRESHOLD` (`90`) |
| `bash/service-health-check.sh` | `MONITORED_SERVICES` (`nginx docker sshd`) |
| `bash/network-monitor.sh` | `PING_TARGETS` (`8.8.8.8 1.1.1.1`), `PING_COUNT` (`3`) |
| `python/process-monitor.py` | `PROCESS_NAME` (`python3`), `CPU_THRESHOLD` (`80`), `MEM_THRESHOLD` (`80`) |
| `python/api-health-check.py` | `API_URL` (empty), `EXPECTED_STATUS` (`200`), `TIMEOUT` (`10`) |
| `python/database-check.py` | `DB_TYPE` (`sqlite`), `DB_HOST` (`localhost`), `DB_NAME` (`test`), `DB_USER`, `DB_PASSWORD` |

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

Each script writes `${SERVICE_NAME}.prom` with `# HELP` and `# TYPE` lines and a
status gauge. The scale is `0=OK, 1=WARNING, 2=CRITICAL`;
`bash/disk-monitor.sh` adds `3=UNKNOWN` and `python/database-check.py` only ever
reports 0 or 2. The exact scale is documented in the `# HELP` line of each
metric. See [docs/PROMETHEUS_INTEGRATION.md](docs/PROMETHEUS_INTEGRATION.md).

## Requirements

**Minimal:**
- Bash 4.0+ for the Bash templates; `bash/generic-monitor.sh` uses the `${VAR^^}`
  case conversion introduced in Bash 4
- Python 3.10+ for the Python templates
- systemd, for the unit templates and the StateDirectory pattern

**Required for one template:**
- `psutil` for `python/process-monitor.py`

**Optional:**
- Node Exporter with textfile collector, for the Prometheus export
- A Telegram bot, for alerts from the two generic templates

## Documentation

| Document | Description |
|----------|-------------|
| [SETUP.md](docs/SETUP.md) | Deployment guide |
| [STATEDIRECTORY_PATTERN.md](docs/STATEDIRECTORY_PATTERN.md) | Why StateDirectory matters |
| [PROMETHEUS_INTEGRATION.md](docs/PROMETHEUS_INTEGRATION.md) | Metrics export guide |
| [DEVICE_PROFILES.md](docs/DEVICE_PROFILES.md) | Multi-server configuration pattern |
| [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common issues and fixes |
| [CHANGELOG.md](CHANGELOG.md) | Release history |
| [SECURITY.md](SECURITY.md) | Reporting a vulnerability |

## Use Cases

The eight templates cover disk usage, systemd service health, network reachability,
process CPU and memory, HTTP endpoints and database connectivity. Anything else
starts from a generic template: it brings the state handling, the rate-limiting,
the metric writer and the logging, and leaves you the check itself.

## Design Notes

**The StateDirectory pattern came from an incident**, not from a style guide: a
monitor kept its deduplication timestamps in `RuntimeDirectory` and sent the
same alert after every run. The unit template now carries the reasoning, a
verification checklist and five common pitfalls in its comments.

**Metrics are written to a temporary file and moved into place.** Prometheus
scrapes the textfile collector on its own schedule, and a direct write can be
read half-finished.

**The example stack has no copies.** Until v1.2.0 `examples/complete-stack/`
carried its own `disk-monitor.sh`, which drifted three releases behind the real
template and lost rate-limiting and atomic writes along the way. It now reads
the templates from `bash/`.

**Placeholders are `{{double_braced}}` and listed in each unit header**, so a
forgotten one is a `grep '{{' /etc/systemd/system/*.service` away.

## License

MIT License, see [LICENSE](LICENSE).

## Author

Marc Allgeier ([@fidpa](https://github.com/fidpa))

## Contributing

Issues and pull requests are welcome, see [CONTRIBUTING.md](CONTRIBUTING.md)
for the ShellCheck and Ruff settings CI enforces.

## See Also

- [bash-production-toolkit](https://github.com/fidpa/bash-production-toolkit) - Production Bash libraries
- [server-scripts-cli](https://github.com/fidpa/server-scripts-cli) - Script management CLI
