# Tri-Perimeter Contribution Framework (TPCF)

## Perimeter Declaration

**This project operates at: Perimeter 3 (Community Sandbox)**

## What is TPCF?

The Tri-Perimeter Contribution Framework (TPCF) is a graduated trust model for managing open source contributions. It defines three security perimeters with increasing levels of access and trust requirements.

## The Three Perimeters

### Perimeter 1: Core Team (Trusted Write Access)
**Status**: Not applicable to this project

- **Access**: Direct commit to `main`/`develop` branches
- **Requirements**:
  - Long-term maintainer status
  - GPG-signed commits
  - 2FA enabled
  - Legal agreements (CLA/DCO)
  - Background verification (for high-security projects)

- **Granted To**: N/A (project uses PR-only workflow)

### Perimeter 2: Established Contributors (Elevated Privileges)
**Status**: Not applicable yet (project is new)

- **Access**:
  - Can merge PRs after review
  - Can triage issues
  - Can create branches in main repo

- **Requirements**:
  - 6+ months of quality contributions
  - Consistent code review participation
  - Community endorsement
  - 2FA enabled

- **Granted To**: None yet

### Perimeter 3: Community Sandbox (Public Contribution) ✓
**Status**: **ACTIVE - This is our current perimeter**

- **Access**:
  - Fork repository
  - Create pull requests
  - Report issues
  - Participate in discussions
  - No direct write access

- **Requirements**:
  - GitHub account
  - Agree to Code of Conduct
  - Follow contribution guidelines

- **Granted To**: **Everyone**

## Our TPCF Policy

### Current Perimeter: 3 (Community Sandbox)

All contributions are welcome via:
1. Fork this repository
2. Create feature branch
3. Submit pull request
4. Pass CI/CD checks
5. Obtain maintainer approval
6. Merge to `main`

### Security Model

**Why Perimeter 3?**
- **Transparency**: All changes reviewed publicly
- **Safety**: No direct write access reduces accident risk
- **Reversibility**: Git enables complete rollback
- **Quality**: Mandatory CI/CD and code review
- **Inclusion**: Low barrier to entry

### Path to Inner Perimeters

#### To Perimeter 2 (Est. 6-12 months):
1. Contribute consistently (10+ merged PRs)
2. Demonstrate code quality
3. Help review others' PRs
4. Engage positively in community
5. Enable 2FA
6. Nomination by current maintainer

#### To Perimeter 1 (Unlikely for this project):
- Project currently uses PR-only workflow
- Direct commit access not granted
- Future re-evaluation possible

## Access Control Matrix

| Activity | Perimeter 1 | Perimeter 2 | Perimeter 3 |
|----------|-------------|-------------|-------------|
| Fork repo | ✓ | ✓ | ✓ |
| Report issues | ✓ | ✓ | ✓ |
| Submit PRs | ✓ | ✓ | ✓ |
| Review PRs | ✓ | ✓ | ✗ |
| Merge PRs | ✓ | ✓ | ✗ |
| Triage issues | ✓ | ✓ | ✗ |
| Push to main | ✗ | ✗ | ✗ |
| Create releases | ✓ | ✗ | ✗ |
| Manage CI/CD | ✓ | ✗ | ✗ |
| Security responses | ✓ | ✓ (disclosed) | ✗ |

## Security Considerations

### Perimeter 3 Protections
- **PR-based workflow**: All changes reviewed
- **CI/CD gates**: Automated testing, linting, security scans
- **Code review**: Human verification
- **Signed commits**: Encouraged (not required)
- **Branch protection**: `main` is protected

### Attack Surface Minimization
- No direct commit access
- No CI/CD secret exposure to forks
- Dependency scanning (Dependabot)
- SAST (Semgrep)
- Regular security audits

## Contribution Process (Perimeter 3)

1. **Fork** the repository
2. **Clone** your fork
3. **Create** feature branch (`git checkout -b feature/my-feature`)
4. **Develop** with tests
5. **Commit** with conventional commits
6. **Push** to your fork
7. **Submit** PR to `main`
8. **CI/CD** runs automatically
9. **Review** by maintainer
10. **Merge** after approval

## Trust Verification

### For Contributors (Perimeter 3)
- ✓ Automated tests pass
- ✓ Code review approval
- ✓ CI/CD gates pass
- ✓ No security issues

### For Maintainers (Perimeter 1/2)
- ✓ 2FA enabled
- ✓ GPG-signed commits (recommended)
- ✓ Active participation
- ✓ Code of Conduct adherence

## Emotional Safety

TPCF supports **psychological safety** through:
- **Perimeter 3 protections**: Contributors can experiment safely
- **Reversibility**: Git enables undo
- **No shame**: PR rejections are learning opportunities
- **Transparency**: Clear contribution path

## Updates to Perimeters

This document may be updated as the project matures. Changes will be:
- Announced in CHANGELOG.md
- Discussed in GitHub Discussions
- Voted on by maintainers

## References

- **TPCF Specification**: [rhodium-minimal example](https://github.com/your-repo/rhodium-minimal)
- **Code of Conduct**: [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- **Contributing Guide**: [CONTRIBUTING.md](CONTRIBUTING.md)
- **Security Policy**: [SECURITY.md](SECURITY.md)

## Contact

Questions about TPCF or perimeter access?
- **Email**: maintainers@hyperpolymath.org
- **Discussions**: https://github.com/Hyperpolymath/excel-economic-number-tool-/discussions
- **Issues**: https://github.com/Hyperpolymath/excel-economic-number-tool-/issues

---

**TPCF Version**: 1.0
**Last Updated**: 2025-11-22
**Current Perimeter**: 3 (Community Sandbox)
