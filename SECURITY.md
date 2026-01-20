# Security Policy

## Reporting Vulnerabilities

**Do NOT open public issues for security vulnerabilities.**

Security vulnerabilities in templates can have serious consequences for users deploying these scripts in production. We take security seriously and appreciate responsible disclosure.

### How to Report

Use GitHub's [Private Vulnerability Reporting](https://github.com/fidpa/linux-monitoring-templates/security/advisories/new) feature.

**Include in your report**:
- Affected template(s) (bash/python, filename)
- Impact assessment (what could an attacker do?)
- Steps to reproduce
- Proof of concept (if applicable)
- Suggested fix (optional)

### Response Timeline

- **Initial response**: Within 48 hours
- **Fix timeline**: Based on severity (see below)
- **Public disclosure**: After fix is released and users have time to update

### Severity Levels

| Severity | Fix Timeline | Examples |
|----------|--------------|----------|
| **Critical** | 24 hours | Command injection, privilege escalation |
| **High** | 7 days | Information disclosure, DoS |
| **Medium** | 30 days | Logic errors, configuration issues |
| **Low** | 90 days | Minor issues, documentation |

## Supported Versions

| Version | Supported |
|---------|-----------|
| v1.x    | ✅ Security updates |
| < v1.0  | ❌ No longer supported |

## Security Best Practices

When using these templates:
- **Review before deploying**: Always review templates before production use
- **Restrict permissions**: Use `DynamicUser=yes` in systemd services
- **Audit state files**: Check `/var/lib/<service>/` permissions regularly
- **Update regularly**: Pull latest versions for security fixes
- **Follow hardening**: Use systemd security directives in templates

## Known Security Considerations

### StateDirectory Pattern
- State files in `/var/lib/<service>/` are owned by service user
- Potential race conditions if multiple instances run (not supported)
- State files contain alert timestamps and metrics (not sensitive)

### Telegram Webhooks
- Webhook URLs contain secrets (store in environment, not state files)
- HTTPS recommended (plain HTTP sends tokens in clear)
- Rate limiting protects against abuse

### Prometheus Metrics
- Textfile collector writes to `/var/lib/node_exporter/textfile_collector/`
- World-readable (metrics are not sensitive)
- No authentication (metrics endpoint typically firewalled)

## Acknowledgments

We appreciate the security research community and will acknowledge reporters in:
- CHANGELOG.md (with permission)
- GitHub Security Advisories
- Credits in documentation
