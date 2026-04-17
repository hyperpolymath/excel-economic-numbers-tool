# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Complete BEA, Census, Eurostat, BIS data source implementations
- Web-based version (WASM + Julia HTTP server)
- Real-time data streaming
- Advanced econometric models (VAR, VECM, GARCH)
- Data visualization components
- Natural language query interface

## [2.0.0-dev] - 2025-11-22

### Added

#### Core Infrastructure
- Julia backend with HTTP/QUIC server (port 8080)
- Cross-platform abstraction layer (ISpreadsheetAdapter)
- OfficeJsAdapter for Microsoft Excel integration
- UnoAdapter for LibreOffice Calc integration (ES5-compatible)
- SQLite-based persistent cache with TTL
- Rate limiting (sliding window, per-source limits)
- Exponential backoff retry logic (2s → 4s → 8s)
- Production-grade error handling

#### Data Sources (10)
- **Complete Implementations**:
  - FRED (Federal Reserve Economic Data) - 120/min rate limit
  - World Bank - 60/min rate limit
  - IMF (International Monetary Fund) - 60/min
  - OECD (Organisation for Economic Co-operation) - 60/min
  - DBnomics (Data aggregator, 70+ providers) - 500/min
  - ECB (European Central Bank) - 60/min

- **Stubs** (future implementation):
  - BEA (Bureau of Economic Analysis)
  - Census Bureau
  - Eurostat
  - BIS (Bank for International Settlements)

#### Economic Formulas
- **Elasticity Calculations**:
  - Price elasticity (4 methods: midpoint, arc, point, log-log)
  - Income elasticity
  - Cross-price elasticity

- **GDP Growth Rates**:
  - Year-over-Year (YoY)
  - Quarter-over-Quarter (QoQ, annualized)
  - Month-over-Month (MoM, annualized)
  - Compound Annual Growth Rate (CAGR)
  - Real vs nominal GDP
  - Growth decomposition
  - Component contribution analysis

- **Inequality Measures**:
  - Gini coefficient
  - Lorenz curve
  - Atkinson index (configurable ε)
  - Theil index
  - Percentile ratios (P90/P10, etc.)
  - Palma ratio

- **Constraint System**:
  - Economic identity solver
  - GDP identity (GDP = C + I + G + NX)
  - Multi-equation systems
  - Fixed vs free variables
  - Iterative convergence (Gauss-Seidel style)

#### Build & Development
- Justfile with 30+ build recipes
- GitLab CI/CD pipeline (6 stages: lint, test, build, security, deploy, release)
- GitHub Actions workflow
- Containerfile for Podman/Docker deployment
- Bootstrap script for dependency checking
- Deployment automation script

#### Configuration
- TypeScript config (tsconfig.json, webpack, jest, eslint, prettier)
- ReScript config (bsconfig.json)
- Julia project (Project.toml)
- Node package (package.json)

#### Documentation
- Comprehensive README (1000+ lines)
- Architecture documentation with ASCII diagrams
- Data sources guide (all 10 sources documented)
- API reference (1500+ lines)
- Developer guide (800+ lines, step-by-step tutorials)
- Contributing guidelines
- Code of Conduct
- Security policy

#### Testing
- Julia unit tests (300+ test cases):
  - Rate limiter tests
  - Elasticity formula tests
  - GDP growth tests
  - Inequality measure tests
  - Constraint system tests
- TypeScript unit tests
- Integration test framework
- Test coverage reporting

#### Examples
- Basic usage examples (7 scenarios)
- Advanced usage examples (7 scenarios)
- Real-world distribution analysis

#### UI Components (ReScript)
- DataBrowser task pane
- FormulaBuilder task pane
- Ribbon tabs structure (planned: 5 tabs)

#### Deployment Artifacts
- Office.js manifest.xml for Excel add-in
- LibreOffice .oxt package description
- Container image configuration

### Changed
- N/A (initial release)

### Deprecated
- N/A (initial release)

### Removed
- N/A (initial release)

### Fixed
- N/A (initial release)

### Security
- Input validation for all user inputs
- Parameterized SQL queries (SQLite)
- HTTPS-only API communication
- API key environment variable storage
- Sandboxed execution (Excel, LibreOffice)
- No eval() or dynamic code execution
- Automated security scanning (npm audit, Pkg.audit())
- SAST via Semgrep
- Dependabot vulnerability monitoring

## [0.0.0] - Project Inception

### Added
- Initial project concept
- CLAUDE.md specification document

---

## Version Numbering

We follow [Semantic Versioning](https://semver.org/):

Given a version number MAJOR.MINOR.PATCH, increment:
- MAJOR: Incompatible API changes
- MINOR: Backwards-compatible functionality
- PATCH: Backwards-compatible bug fixes

Additional labels for pre-release: `-alpha`, `-beta`, `-rc`, `-dev`

## Links

- [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
- [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
- [Conventional Commits](https://www.conventionalcommits.org/)

## Future Releases

### 2.1.0 (Planned Q1 2026)
- Complete remaining data source stubs
- Data visualization components
- Export to CSV, JSON, Parquet
- Enhanced UI components

### 2.5.0 (Planned Q3 2026)
- Web-based version (WASM)
- Real-time data streaming
- Advanced econometric models
- Collaborative features

### 3.0.0 (Planned 2027)
- Machine learning integration
- Natural language queries
- Automated report generation
- Multi-language support (i18n)
