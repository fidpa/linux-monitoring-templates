# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2026-01-17

### Fixed
- **disk-monitor.sh**: Fixed critical status mapping bug where ERROR status was incorrectly mapped to 0 (OK) instead of 3 (UNKNOWN)
- **generic-monitor.sh**: Fixed Telegram message formatting - literal `\n` escapes now render as actual newlines
- Resolved 5 ShellCheck warnings:
  - SC2181: Check exit code directly instead of using `$?`
  - SC2076: Fixed regex pattern matching in array search
  - SC1090: Added shellcheck directive for dynamic source paths

### Changed
- Removed false "Smart rate-limiting" claims from script headers:
  - `bash/disk-monitor.sh`
  - `bash/service-health-check.sh`
  - `bash/network-monitor.sh`
  - `python/api-health-check.py`
  - `python/database-check.py`
- Updated `docs/SETUP.md` to clarify that rate-limiting is only implemented in `generic-monitor.sh`
- Fixed repository URLs in systemd templates (`monitoring-templates` → `linux-monitoring-templates`):
  - `systemd/monitor.service.template`
  - `systemd/monitor.timer.template`

### Technical Details
- **Impact**: ERROR states in disk monitoring now correctly export status=3 instead of status=0
- **Scope**: 8 files modified (4 Bash, 2 Python, 1 docs, 2 systemd templates)
- **Quality**: Zero ShellCheck warnings, zero Python syntax errors

## [1.0.0] - 2026-01-03

### Added
- Initial public release
- Production-ready monitoring templates (Bash & Python)
- StateDirectory pattern for persistent state management
- Smart rate-limiting with configurable cooldowns
- Prometheus metrics integration
- systemd service and timer templates
- Telegram alert integration
- Security hardening in systemd templates
- Comprehensive documentation (README, SETUP, troubleshooting)

### Templates Included
**Bash Scripts:**
- `disk-monitor.sh` - Disk usage monitoring
- `service-health-check.sh` - systemd service health checks
- `network-monitor.sh` - Network connectivity monitoring
- `generic-monitor.sh` - Customizable monitoring template

**Python Scripts:**
- `api-health-check.py` - HTTP/HTTPS endpoint monitoring
- `database-check.py` - Database connectivity checks
- `process-monitor.py` - Process resource monitoring
- `generic-monitor.py` - Customizable Python monitoring template

**systemd Templates:**
- `monitor.service.template` - Service unit with StateDirectory pattern
- `monitor.timer.template` - Timer unit with scheduling examples

---

[1.0.1]: https://github.com/fidpa/linux-monitoring-templates/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/fidpa/linux-monitoring-templates/releases/tag/v1.0.0
