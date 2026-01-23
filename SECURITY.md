# Security Policy

## Supported Versions

We release patches for security vulnerabilities. Currently supported versions:

| Version | Supported          |
| ------- | ------------------ |
| 2.0.x   | :white_check_mark: |
| < 2.0   | :x:                |

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

Instead, please report them via one of the following methods:

### Preferred: Security Advisory

Use GitHub's Security Advisory feature:
1. Go to the repository's Security tab
2. Click "Report a vulnerability"
3. Fill out the form with details

### Email

Send details to: security@hyperpolymath.org

Please include:
- Type of issue (e.g., buffer overflow, SQL injection, cross-site scripting, etc.)
- Full paths of source file(s) related to the manifestation of the issue
- Location of the affected source code (tag/branch/commit or direct URL)
- Any special configuration required to reproduce the issue
- Step-by-step instructions to reproduce the issue
- Proof-of-concept or exploit code (if possible)
- Impact of the issue, including how an attacker might exploit it

### Response Timeline

- **Acknowledgment**: Within 48 hours
- **Initial assessment**: Within 5 business days
- **Status updates**: Every 7 days until resolved
- **Disclosure timeline**: 90 days from initial report (may be extended by mutual agreement)

## Security Disclosure Policy

When we receive a security bug report, we will:

1. Confirm the problem and determine affected versions
2. Audit code to find any similar problems
3. Prepare fixes for all supported releases
4. Release patches as soon as possible

## Security Considerations

### Data Sources

This project fetches data from external economic data APIs:
- All API calls use HTTPS
- API keys are stored in environment variables, never in code
- Rate limiting prevents abuse
- Responses are validated before processing

### Cache Security

- SQLite cache stored at `~/.economic-toolkit/cache/data.db`
- No sensitive credentials cached
- Cache is user-specific (not shared)
- No remote access to cache

### Input Validation

All user inputs are validated:
- Date ranges checked for validity
- Series IDs sanitized
- Numeric inputs bounds-checked
- SQL injection prevention via parameterized queries

### Dependencies

We monitor dependencies for known vulnerabilities:
- `npm audit` runs in CI/CD
- Julia `Pkg.audit()` in CI/CD
- Automated security updates via Dependabot
- Minimal dependency footprint

### Office.js Security

Excel add-in operates in sandboxed environment:
- Limited to user's workbook
- No file system access beyond Office.js API
- HTTPS-only communication with backend
- No eval() or dynamic code execution

### LibreOffice Security

UNO extension security:
- No unsafe operations
- Sandboxed execution
- User permission required for data access

## Known Security Limitations

1. **API Key Security**: Users must protect their own API keys (FRED_API_KEY, etc.)
2. **Network Security**: Backend server (port 8080) should not be exposed to internet
3. **Cache Permissions**: Users responsible for securing their cache directory
4. **HTTPS**: Production deployment should use HTTPS reverse proxy

## Security Best Practices for Users

1. **API Keys**: Store in `.env` or environment variables, never commit to git
2. **Local Deployment**: Run backend on localhost only
3. **Production**: Use reverse proxy (nginx) with HTTPS
4. **Updates**: Keep dependencies updated (`just update`)
5. **Audits**: Run `just security` regularly

## Security Audits

This project undergoes:
- Automated security scanning in CI/CD
- Manual code review for all changes
- Dependency vulnerability scanning
- SAST (Static Application Security Testing) via Semgrep

Last security audit: 2025-11-22

## Acknowledgments

We thank the following researchers for responsibly disclosing vulnerabilities:

- *No vulnerabilities reported yet*

## References

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CWE/SANS Top 25](https://www.sans.org/top25-software-errors/)
- [RFC 9116: security.txt](https://www.rfc-editor.org/rfc/rfc9116.html)

---

This security policy complies with:
- RFC 9116 (security.txt)
- ISO/IEC 29147 (Vulnerability disclosure)
- ISO/IEC 30111 (Vulnerability handling)
