# Contributing to linux-monitoring-templates

Thank you for considering contributing to linux-monitoring-templates! This project provides production-ready monitoring script templates with StateDirectory pattern and systemd best practices.

## How to Contribute

### Bug Reports

Open an issue with:
- **Template affected**: Which template (bash/python) and which file
- **Expected vs actual behavior**: What should happen vs what actually happens
- **Steps to reproduce**: Minimal example to reproduce the issue
- **System info**: OS, Bash/Python version, systemd version

### Feature Requests

Open an issue describing:
- **Use case**: What problem does this solve?
- **Proposed solution**: How should it work?
- **Alternatives considered**: Other approaches you've thought about

### Pull Requests

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run linters:
   ```bash
   # Bash templates
   shellcheck bash/*.sh

   # Python templates
   ruff check python/*.py
   ```
5. Commit changes (see [Commit Message Format](#commit-message-format))
6. Push to your fork and open a Pull Request

## Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/linux-monitoring-templates
cd linux-monitoring-templates

# Test Bash templates
shellcheck bash/*.sh

# Test Python templates (requires ruff)
pip install ruff
ruff check python/*.py

# Test a template locally
bash bash/disk-monitor.sh --test
```

## Code Style

### Bash Templates
- **ShellCheck compliance**: All scripts must pass `shellcheck`
- **Best practices**: Use `set -uo pipefail`
- **Error handling**: Explicit error codes, no silent failures
- **Documentation**: Function headers with purpose and parameters

### Python Templates
- **Ruff compliance**: All scripts must pass `ruff check`
- **Type hints**: Use Python 3.10+ type hints (`dict[str, Any]`, `list[str] | None`)
- **Exit codes**: `main() -> int` with `sys.exit(main())`
- **Security**: Use `yaml.safe_load()`, `pathlib`, avoid `shell=True`

### systemd Units
- **StateDirectory pattern**: Persistent state in `/var/lib/<service>/`
- **Security hardening**: `DynamicUser=yes`, `ProtectSystem=strict`, etc.
- **Documentation**: Inline comments explaining non-obvious settings

## Commit Message Format

Use semantic commit messages:
```
type: short description

Optional longer description explaining the change.
```

**Types**:
- `feat`: New feature or template
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting)
- `refactor`: Code refactoring
- `test`: Test additions or changes
- `chore`: Build/maintenance tasks

**Examples**:
```
feat: add postgresql-monitor.sh template

docs: clarify StateDirectory pattern in README

fix: handle missing state file in disk-monitor.sh
```

## Questions?

Open a GitHub issue with the `question` label or start a discussion.
