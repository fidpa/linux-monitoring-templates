# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] - 2026-08-08

### Added
- **`METRICS_DIR` is configurable in the Python templates**: the path was
  hardcoded to `/var/lib/node_exporter/textfile_collector`, which made the
  metrics path untestable without root. The Bash templates already honoured the
  variable; all eight now behave the same
- **`ruff.toml`**: pins the lint rule set (`E4`, `E7`, `E9`, `F`, `I`) so CI
  results do not depend on which Ruff version `pip install ruff` happens to
  fetch
- **systemd units for the complete-stack example**: `service-health-check` and
  `network-monitor` (service + timer each). The example claimed to deploy
  "disk, service, and network monitoring" but shipped units for disk only
- **`.github/ISSUE_TEMPLATE/config.yml`**: routes security reports to GitHub
  Security Advisories and questions to Discussions

### Fixed
- **Metrics were written non-atomically in all eight templates**: every script
  wrote straight to the final `.prom` path (`cat > "$METRICS_FILE"` /
  `open(METRICS_FILE, 'w')`), so Node Exporter could scrape a half-written
  file. All templates now write to a temp file beside the target, `chmod 644`
  it, and rename it into place. The README advertised this property and
  `docs/PROMETHEUS_INTEGRATION.md` documented the pattern -- but no template
  implemented it
- **`database-check.py` created the database it was meant to check**: with the
  defaults (`DB_TYPE=sqlite`, `DB_NAME=test`), `sqlite3.connect()` creates a
  missing file, so the check reported `connected=1` for a database it had just
  invented and left an empty file `test` in the working directory. It now opens
  the file read-only (`file:...?mode=ro`) and reports CRITICAL when it is
  missing
- **`generic-monitor.sh` misreported an unwritable lock directory**: when
  `/run/${SERVICE_NAME}.lock` could not be created, the script logged "Another
  instance is running (lock held)" and sent the reader looking for a process
  that did not exist. Both cases are now distinct, and the error names
  `LOCK_DIR`
- **Three documentation links returned 404**: GitHub URLs pointing at
  repository files need `/blob/main/`. Affected `bash/generic-monitor.sh`,
  `python/generic-monitor.py` and `systemd/monitor.service.template`
- **A dead line suggested the scripts created the metrics directory**:
  `[[ -d "$METRICS_DIR" ]] && mkdir -p "$METRICS_DIR"` only ran when the
  directory already existed. Removed; the opt-in behaviour is now stated in the
  code and in the Prometheus guide's troubleshooting section
- **Release notes were effectively empty**: `release.yml` used
  `generate_release_notes: true`, which builds notes from commit messages --
  and every release commit in this repository is a bare `vX.Y.Z` line. The
  v1.2.0 release body was 95 characters (a compare link) while its CHANGELOG
  section held 762. The workflow now extracts the CHANGELOG section for the tag
  and fails when it finds none
- **`--dry-run` in `examples/complete-stack/deploy.sh` required root**, even
  though it changes nothing

### Changed
- **The complete-stack example no longer carries its own copy of a monitor**:
  `examples/complete-stack/monitors/disk-monitor.sh` had drifted three releases
  behind `bash/disk-monitor.sh` (47 lines against 135) and had lost
  rate-limiting, the StateDirectory pattern and atomic writes, while its header
  still called it production-ready. `deploy.sh` now installs the templates from
  `bash/` directly, driven by a named `MONITORS` list
- **Removed the `Version:` header line from eleven files**: both systemd
  templates, all four Bash templates, all four Python templates and
  `deploy.sh`. They still read `1.0.1` (`deploy.sh`: `1.0.0`) three releases
  after the fact. The version lives in the git tag and this changelog, nowhere
  else
- **`release.yml`**: `softprops/action-gh-release` v1 -> v2
- **`process-monitor.py`**: import order normalized (Ruff `I001`)

### Upgrade notes
- **`database-check.py` with SQLite will now report CRITICAL where it
  previously reported OK**, whenever `DB_NAME` points at a file that does not
  exist. That is the intended behaviour -- the previous result was an artefact
  of SQLite creating the file -- but an alert may fire on the first run after
  upgrading. Check that `DB_NAME` holds the full path to the database file;
  relative names resolve against the service's working directory
- **Metrics files are now created with mode 644 explicitly.** If a deployment
  relied on a restrictive umask to keep them unreadable, that no longer holds.
  Node Exporter runs as its own user and has to read them
- **Anyone deploying from `examples/complete-stack/`** should re-run
  `deploy.sh` from a full checkout: the scripts are now read from `../../bash/`
  and the deployment covers three monitors instead of one

### Technical Details
- **Impact**: 8 templates changed behaviour (atomic writes), 1 template changed
  its verdict for a missing SQLite file, 11 files lost a stale version header
- **Scope**: 22 files (4 Bash, 4 Python, 2 systemd templates, 6 example files,
  README, Prometheus guide, 2 workflow/config files, `.gitignore`)
- **Quality**: ShellCheck (`--severity=error`), Ruff against the pinned rule
  set, `bash -n`, `py_compile`, `yamllint` and `gitleaks dir` all clean; all
  eight templates were run once and verified to write a mode-644 `.prom` file
  with no leftover `.tmp`
- **CI/CD**: `lint.yml` was red before this release -- Ruff 0.16's wider
  default rule set reported 15 findings on an unchanged tree. `ruff.toml`
  restores a reproducible contract

## [1.2.0] - 2026-01-21

### Added
- **Python Linting in CI**: Ruff linting now validates all Python templates on push/PR
- **Python Syntax Validation**: `py_compile` check added to CI pipeline

### Fixed
- **Python Templates**: Removed 17 unnecessary f-string prefixes (Ruff F541)
  - `api-health-check.py`: 6 fixes in `export_metrics()`
  - `database-check.py`: 6 fixes in `export_metrics()`
  - `process-monitor.py`: 5 fixes in `export_metrics()`

### Changed
- **CI Pipeline**: `lint.yml` now runs 3 parallel jobs:
  - ShellCheck (bash/, examples/)
  - Ruff (python/)
  - Syntax Validation (Bash + Python)

### Technical Details
- **Quality**: All templates pass ShellCheck, Ruff, and syntax validation
- **CI/CD Coverage**: 100% of Bash AND Python scripts validated on every push

## [1.1.0] - 2026-01-21

### Added
- **CI/CD Pipeline**: GitHub Actions workflows for automated quality assurance
  - `lint.yml`: ShellCheck validation + Bash syntax checks on push/PR
  - `release.yml`: Automatic GitHub releases on version tags
- **Community Files**: Professional open-source project standards
  - `CONTRIBUTING.md`: Contribution guidelines with code style requirements
  - `SECURITY.md`: Vulnerability reporting process and security best practices
  - `.github/ISSUE_TEMPLATE/bug_report.md`: Structured bug report template
  - `.github/ISSUE_TEMPLATE/feature_request.md`: Feature request template
  - `.github/pull_request_template.md`: Pull request template with testing checklist
- **ShellCheck Configuration**: `.shellcheckrc` (Best Practices 2025 compliant)

### Changed
- **README.md**: Updated badges
  - Added CI status badge (live workflow status)
  - Replaced static ShellCheck badge with dynamic CI badge
  - Current badges: License, CI, Bash, Python, Templates, GitHub Stars, Last Commit (7 total)

### Technical Details
- **Quality**: All templates pass ShellCheck (severity=error) and Bash syntax validation
- **CI/CD Coverage**: 100% of Bash scripts (bash/, examples/) validated on every push
- **Community Standards**: Repository now follows GitHub best practices for open-source projects

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

[1.3.0]: https://github.com/fidpa/linux-monitoring-templates/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/fidpa/linux-monitoring-templates/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/fidpa/linux-monitoring-templates/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/fidpa/linux-monitoring-templates/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/fidpa/linux-monitoring-templates/releases/tag/v1.0.0
