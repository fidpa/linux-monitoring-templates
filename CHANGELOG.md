# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.4] - 2026-08-28: GitHub identifies the project as MIT-licensed

### Changed

- **The repository page shows the MIT licence, and licence-filtered searches
  find the project.** `LICENSE` carried the repository URL on its own line
  under the copyright notice. GitHub reads a licence text with an extra line as
  modified and reports `NOASSERTION`, which leaves the licence field on the
  repository page empty. The line is gone; the MIT text and the copyright
  notice are byte-for-byte unchanged, and the URL is still in `README.md`.

## [1.3.3] - 2026-08-28: Documentation names the two templates that actually alert

Six of the eight templates export Prometheus metrics and nothing else. The
README, the setup guide and five file headers described them as if they alerted,
rate-limited and sent Telegram messages. v1.0.1 had already removed that claim
from five script headers and corrected `docs/SETUP.md`; the README kept it, and
so did a sixth header nobody had looked at. This release finishes that pass.

### Fixed
- **The README advertised alerting features for all eight templates**: the
  tagline, three entries in the feature list, the "Smart Alerting" block and one
  line under "Why These Templates" now name `generic-monitor.sh` and
  `generic-monitor.py`, which are the two templates that implement them
- **Five file headers claimed to send alerts**: `disk-monitor.sh`,
  `service-health-check.sh`, `network-monitor.sh`, `process-monitor.py` and
  `api-health-check.py` opened with "sends alerts on failures" or the equivalent.
  None of them contains a single send call; they export metrics and exit with a
  status code, which is what the headers now say
- **`process-monitor.py` still listed "Smart rate-limiting" as a feature**: the
  same claim v1.0.1 removed from five other headers. It has no rate-limiting
  code
- **`docs/SETUP.md` exempted three templates where six apply**: the note named
  the specialized Bash monitors only, leaving `process-monitor.py`,
  `api-health-check.py` and `database-check.py` looking as though they alert
- **The advertised cooldown default was right for one of the two generics**:
  the README said three hours. `RATE_LIMIT_SECONDS` in `generic-monitor.sh`
  defaults to 10800 seconds, `ALERT_COOLDOWN` in `generic-monitor.py` to 21600
- **`psutil` was listed as optional**: `process-monitor.py` imports it at module
  level and cannot run without it. The README also listed `requests`, which no
  template imports; all HTTP calls use `urllib.request` from the standard
  library
- **`disk-monitor.sh` documented an environment variable for a feature it does
  not have**: `DEVICE_NAME - Device name for alerts`. The variable itself is
  unchanged, see the upgrade note

### Upgrade notes
- **No template changed its behaviour.** This release corrects documentation and
  file headers; every threshold, metric name, exit code and environment variable
  works exactly as it did in v1.3.2
- **`DEVICE_NAME` is set but unused in all six specialized templates.** Only
  `generic-monitor.sh` and `generic-monitor.py` read it, for `TELEGRAM_PREFIX`.
  Setting it on the others has never had an effect. It is left in place because
  it is the variable you need once you copy the alerting in; removing it is a
  separate decision

### Technical Details
- **Scope**: 8 files (README, `docs/SETUP.md`, three Bash templates, two Python
  templates, CHANGELOG)
- **Quality**: ShellCheck (`--severity=error`), Ruff against the pinned rule set,
  `bash -n`, `py_compile`, `yamllint` and `gitleaks dir` all clean

## [1.3.2] - 2026-08-28: Release notes match the tags they are published under

The release pages of this repository carried less than the changelog did. Two of
the four releases had no notes at all beyond the compare link GitHub generates,
all four titles repeated the tag name that already stands beside them in the
release list, and two compare links at the end of this file pointed at a tag
that was never created. This release brings the published record in line with
the tree it describes.

### Changed
- **Every release title now carries a headline**: the version headings in this
  file end in `: <headline>`, and `release.yml` reads the title from there. The
  release list previously showed `v1.3.1` four times over, which the version
  number beside it already said
- **The older sections were checked against the tags they describe and
  corrected where the code contradicted them.** Each correction is a separate
  entry below. Every measured value, path and function name that held up is
  unchanged, and no tag was moved
- **`[1.0.0]` and `[1.0.1]` link to a commit instead of a tag**: both pointed at
  `v1.0.0`, which the repository never carried, so both returned 404. They now
  reference `3799c77`, the commit the initial release was published from

### Fixed
- **The initial release advertised rate-limiting and Telegram alerts for the
  whole set**: both exist in `bash/generic-monitor.sh` and
  `python/generic-monitor.py` only. v1.0.1 already removed the same claim from
  five script headers; the `[1.0.0]` section kept it. It now names the two
  templates that carry the feature
- **The `[1.0.1]` scope line counted wrong**: it read "8 files modified (4 Bash,
  2 Python, 1 docs, 2 systemd templates)", which adds up to 9, and the release
  touched 4 Python files, not 2. The line now states the 16 files the tag
  changed
- **`[1.0.1]` did not mention that it cleared the execute bit on ten files**:
  the four Bash templates, the four Python templates and both example scripts
  went from mode 755 to 644 in that tag. For `bash/` and `python/` that matches
  the convention `ruff.toml` documents, but it is what broke
  `examples/complete-stack/deploy.sh` until v1.3.1
- **`[1.0.1]` shifted an exported metric value without an upgrade note**:
  `disk_monitor_status` began reporting `3` where it had reported `0`. The
  section now carries `### Upgrade notes`
- **The `[1.3.0]` scope breakdown was short by one**: the list in brackets adds
  up to 21 against the 22 files it claims. `ruff.toml` was missing from it
- **An arrow character stood in the `[1.0.1]` section**: this file is ASCII

## [1.3.1] - 2026-08-12: The example stack deploy script runs again

### Fixed
- **The quick start for the example stack failed with "Permission denied"**:
  the README documents `cd examples/complete-stack && sudo ./deploy.sh`, but
  `examples/complete-stack/deploy.sh` carried mode 644 since v1.0.1, and Linux
  requires at least one execute bit before `exec()` runs a file, regardless of
  privilege. Restored to mode 755. This is the deploy script for the example
  stack, not a copy-paste template, so it is unrelated to the "templates ship
  non-executable" convention `ruff.toml` documents for `bash/` and `python/`

## [1.3.0] - 2026-08-08: Metrics are written atomically and the database check stops creating its target

### Added
- **The metrics path is configurable in the Python templates**: `METRICS_DIR`
  was hardcoded to `/var/lib/node_exporter/textfile_collector`, which made the
  path untestable without root. The Bash templates already honoured the
  variable; all eight now behave the same
- **A wider default rule set in a new Ruff release no longer turns CI red**:
  `ruff.toml` pins the lint rule set (`E4`, `E7`, `E9`, `F`, `I`), because
  `lint.yml` installs Ruff unpinned
- **The complete-stack example deploys what it claims to**: it advertised
  "disk, service, and network monitoring" but shipped units for disk only.
  `service-health-check` and `network-monitor` now have a service and a timer
  each
- **Security reports have a route that is not the issue tracker**:
  `.github/ISSUE_TEMPLATE/config.yml` sends them to GitHub Security Advisories
  and questions to Discussions

### Fixed
- **Node Exporter could scrape a half-written metrics file from any of the
  eight templates**: every script wrote straight to the final `.prom` path
  (`cat > "$METRICS_FILE"` / `open(METRICS_FILE, 'w')`). All templates now
  write to a temp file beside the target, `chmod 644` it, and rename it into
  place. The README advertised this property and
  `docs/PROMETHEUS_INTEGRATION.md` documented the pattern, but no template
  implemented it
- **`database-check.py` reported a healthy database it had just created
  itself**: with the defaults (`DB_TYPE=sqlite`, `DB_NAME=test`),
  `sqlite3.connect()` creates a missing file, so the check returned
  `connected=1` and left an empty file `test` in the working directory. It now
  opens the file read-only (`file:...?mode=ro`) and reports CRITICAL when it is
  missing
- **An unwritable lock directory sent the reader looking for a process that did
  not exist**: when `/run/${SERVICE_NAME}.lock` could not be created,
  `generic-monitor.sh` logged "Another instance is running (lock held)". Both
  cases are now distinct, and the error names `LOCK_DIR`
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
- **The version lives in the git tag and this changelog, nowhere else**: the
  `Version:` header line came out of eleven files (both systemd templates, all
  four Bash templates, all four Python templates and `deploy.sh`). They still
  read `1.0.1` (`deploy.sh`: `1.0.0`) three releases after the fact
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
  README, Prometheus guide, `ruff.toml`, 2 workflow/config files, `.gitignore`)
- **Quality**: ShellCheck (`--severity=error`), Ruff against the pinned rule
  set, `bash -n`, `py_compile`, `yamllint` and `gitleaks dir` all clean; all
  eight templates were run once and verified to write a mode-644 `.prom` file
  with no leftover `.tmp`
- **CI/CD**: `lint.yml` was red before this release -- Ruff 0.16's wider
  default rule set reported 15 findings on an unchanged tree. `ruff.toml`
  restores a reproducible contract

## [1.2.0] - 2026-01-21: Python templates are linted on every push

### Added
- **The Python templates are checked on push and pull request**: Ruff runs
  against `python/` in `lint.yml`. They had shipped unlinted since v1.0.0
- **Broken Python syntax is caught before it is tagged**: `py_compile` runs in
  the same workflow

### Fixed
- **17 f-string prefixes on strings with nothing to interpolate** (Ruff F541):
  - `api-health-check.py`: 6 fixes in `export_metrics()`
  - `database-check.py`: 6 fixes in `export_metrics()`
  - `process-monitor.py`: 5 fixes in `export_metrics()`

### Changed
- **`lint.yml` runs three jobs in parallel** instead of two: ShellCheck
  (`bash/`, `examples/`), Ruff (`python/`), and syntax validation for both
  languages

### Technical Details
- **Quality**: All templates pass ShellCheck, Ruff, and syntax validation
- **CI/CD Coverage**: every `.sh` and `.py` file in the repository is validated
  on every push

## [1.1.0] - 2026-01-21: Pushes are linted and tags publish themselves

### Added
- **Every push and pull request is checked before it can be tagged**:
  `.github/workflows/lint.yml` runs ShellCheck and Bash syntax validation
- **A pushed version tag creates its GitHub release**:
  `.github/workflows/release.yml`
- **Contributors find the process written down**: `CONTRIBUTING.md` (code style
  and development setup), `SECURITY.md` (vulnerability reporting),
  `.github/ISSUE_TEMPLATE/bug_report.md`,
  `.github/ISSUE_TEMPLATE/feature_request.md` and
  `.github/pull_request_template.md`
- **ShellCheck reads the same configuration locally and in CI**:
  `.shellcheckrc`

### Changed
- **The README badge row shows live CI state**: the static ShellCheck badge was
  replaced by the workflow status badge. Seven badges total (License, CI, Bash,
  Python, Templates, GitHub Stars, Last Commit)

### Technical Details
- **Quality**: All templates pass ShellCheck (severity=error) and Bash syntax validation
- **CI/CD Coverage**: every `.sh` file in `bash/` and `examples/` is validated on
  every push
- **Community Standards**: Repository now follows GitHub best practices for open-source projects

## [1.0.1] - 2026-01-17: Disk monitor reports UNKNOWN instead of OK when it fails

### Fixed
- **A failed disk check exported the value that means "everything is fine"**:
  `disk-monitor.sh` mapped ERROR to `disk_monitor_status 0` (OK) through a
  catch-all `*)` branch instead of `3` (UNKNOWN). An unreachable mount point
  therefore looked healthy on the dashboard
- **Telegram alerts arrived with literal `\n` in them**: `generic-monitor.sh`
  passed the escape through instead of a newline
- **Five ShellCheck findings in `bash/`**: two `$?` checks replaced by direct
  exit-code tests (SC2181), two intentional literal matches marked (SC2076),
  one dynamic `source` path annotated (SC1090)

### Changed
- **Five scripts advertised rate-limiting they do not implement**: the header
  line came out of `bash/disk-monitor.sh`, `bash/service-health-check.sh`,
  `bash/network-monitor.sh`, `python/api-health-check.py` and
  `python/database-check.py`. It is implemented in `generic-monitor.sh` only,
  which `docs/SETUP.md` now says
- **The systemd templates pointed at a repository name that no longer exists**:
  `monitoring-templates` became `linux-monitoring-templates` in
  `systemd/monitor.service.template` and `systemd/monitor.timer.template`
- **Ten files lost their execute bit** (mode 755 to 644): the four Bash
  templates, the four Python templates, `examples/complete-stack/deploy.sh` and
  `examples/complete-stack/monitors/disk-monitor.sh`. For the templates this is
  intended, they are meant to be copied and made executable by the user; for
  `deploy.sh` it was not, and it stayed broken until v1.3.1

### Upgrade notes
- **`disk_monitor_status` now emits `3` where it emitted `0`** whenever the
  disk check itself fails. Any alert rule written as `disk_monitor_status == 0`
  meaning "healthy" will keep matching, but a rule that treated everything
  other than `1` and `2` as healthy will now see a third value

### Technical Details
- **Impact**: ERROR states in disk monitoring now export status=3 instead of status=0
- **Scope**: 16 files (4 Bash templates, 4 Python templates, 2 systemd
  templates, `docs/SETUP.md`, README, both example scripts, CHANGELOG and one
  stray symlink)
- **Quality**: Zero ShellCheck warnings, zero Python syntax errors

## [1.0.0] - 2026-01-03: Eight monitoring templates built around the StateDirectory pattern

### Added
- Initial public release
- Production-ready monitoring templates (Bash and Python)
- StateDirectory pattern for persistent state management
- Rate-limiting with configurable cooldowns in `bash/generic-monitor.sh` and
  `python/generic-monitor.py`
- Prometheus metrics integration
- systemd service and timer templates
- Telegram alert integration in `bash/generic-monitor.sh` and
  `python/generic-monitor.py`
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

[1.3.4]: https://github.com/fidpa/linux-monitoring-templates/compare/v1.3.3...v1.3.4
[1.3.3]: https://github.com/fidpa/linux-monitoring-templates/compare/v1.3.2...v1.3.3
[1.3.2]: https://github.com/fidpa/linux-monitoring-templates/compare/v1.3.1...v1.3.2
[1.3.1]: https://github.com/fidpa/linux-monitoring-templates/compare/v1.3.0...v1.3.1
[1.3.0]: https://github.com/fidpa/linux-monitoring-templates/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/fidpa/linux-monitoring-templates/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/fidpa/linux-monitoring-templates/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/fidpa/linux-monitoring-templates/compare/3799c77...v1.0.1
[1.0.0]: https://github.com/fidpa/linux-monitoring-templates/commit/3799c77
