<!--
SPDX-License-Identifier: CC-BY-SA-4.0
SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-->

[![Build Status](https://img.shields.io/github/workflow/status/hyperpolymath/excel-economic-numbers-tool/CI)](https://github.com/hyperpolymath/excel-economic-numbers-tool/actions) [![Coverage](https://img.shields.io/codecov/c/github/hyperpolymath/excel-economic-numbers-tool)](https://codecov.io/gh/hyperpolymath/excel-economic-numbers-tool)
[![Version](https://img.shields.io/npm/v/economic-toolkit-v2)](https://www.npmjs.com/package/economic-toolkit-v2)
[![License: MPL-2.0](https://img.shields.io/badge/License-MPL_2.0--1.0-blue.svg)](https://github.com/hyperpolymath/palimpsest-license)
[![RSR Compliance](https://img.shields.io/badge/RSR-89%25%20Bronze-cd7f32)](docs/standards/RSR.md)
[![TPCF](https://img.shields.io/badge/TPCF-Perimeter%203-green)](docs/governance/TPCF.md)

Cross-platform Excel/LibreOffice add-in for economic modeling, data
analysis, and research.

**📖 New to this repository?** See [Navigation Guide](NAVIGATION.adoc)
for directory structure and quick links.

# Features

- **10 Data Sources**: FRED, World Bank, IMF, OECD, ECB, BEA, Census,
  Eurostat, BIS, DBnomics

- **Economic Functions**: Elasticity, GDP growth, inequality metrics
  (Gini, Lorenz)

- **Cross-Platform**: Microsoft Excel (Office.js) and LibreOffice (UNO
  API)

- **Intelligent Caching**: SQLite with configurable TTL

- **Rate Limiting**: Respects API quotas

- **Type-Safe**: Built with AffineScript and Julia

- **Production-Ready**: Comprehensive tests, error handling, logging

# Quick Start

## Excel

1.  Download the latest release from [GitHub
    Releases](https://github.com/hyperpolymath/excel-economic-numbers-tool/releases)

2.  Excel → **Insert** → **Get Add-ins** → **Upload My Add-in**

3.  Select `manifest.xml`

```excel
=ECON.FRED("GDPC1", "2020-01-01", "2023-12-31")
```

## LibreOffice

1.  Download `.oxt` extension from [GitHub
    Releases](https://github.com/hyperpolymath/excel-economic-numbers-tool/releases)

2.  LibreOffice Calc → **Tools** → **Extension Manager** → **Add**

3.  Restart LibreOffice

# Installation

## Prerequisites

- Deno 2.0+

- Julia 1.9+

- AffineScript 12.0+

## Build

```bash
# Install dependencies
deno install

# Build AffineScript
affinescript build

# Run tests
deno test
julia --project tests/runtests.jl

# Build add-in (from .build/ directory)
cd .build && just build

# Or build specific platforms
cd .build && just build-excel    # Excel only
cd .build && just build-libre    # LibreOffice only
```

# Usage

See [API Reference](docs/api/api_reference.md) for detailed function
documentation.

## Fetch Economic Data

```excel
=ECON.FRED("UNRATE", "2020-01-01", "2023-12-31")
=ECON.WORLDBANK("USA", "NY.GDP.MKTP.CD", 2020, 2023)
```

## Calculate Growth Rates

```excel
=ECON.GROWTH_RATE(A1:A10)
=ECON.CAGR(1000, 1500, 5)
```

## Inequality Analysis

```excel
=ECON.GINI(A1:A100)
=ECON.LORENZ_CURVE(A1:A100)
```

# Data Sources

| Source     | Description                        | API Key Required |
|------------|------------------------------------|------------------|
| FRED       | Federal Reserve Economic Data      | Yes              |
| World Bank | Global development indicators      | No               |
| IMF        | International Monetary Fund data   | No               |
| OECD       | Economic statistics                | No               |
| ECB        | European Central Bank data         | No               |
| BEA        | US Bureau of Economic Analysis     | Yes              |
| Census     | US Census Bureau                   | Yes              |
| Eurostat   | European statistics                | No               |
| BIS        | Bank for International Settlements | No               |
| DBnomics   | Aggregated economic databases      | No               |

Configuration: [Data Sources Guide](docs/api/data_sources.md)

# Architecture

    excel-economic-numbers-tool/
    ├── src/
    │   ├── affinescript/       # AffineScript application code
    │   └── julia/          # Julia computational backend
    ├── tests/
    │   ├── affinescript/       # AffineScript tests
    │   └── julia/          # Julia tests
    ├── docs/               # Documentation (organized by purpose)
    │   ├── api/            # Technical documentation
    │   ├── governance/     # Community and contribution docs
    │   ├── standards/      # Compliance documentation
    │   └── changelog/      # Version history
    ├── .build/             # Build system and tooling config
    │   ├── Justfile        # Task automation
    │   ├── Containerfile   # Container image
    │   └── config/         # Tool configurations
    ├── examples/           # Usage examples
    └── scripts/            # Utility scripts

See [Architecture Overview](docs/api/architecture.md) for details.

# Development

See [Developer Guide](docs/api/developer_guide.md) for setup
instructions.

## Language Base

Per [Hyperpolymath Standard](.claude/PROJECT.md):

- ✅ AffineScript (primary application code)

- ✅ Julia (data processing, batch scripts)

- ✅ Deno (runtime, package management)

- ✅ Rust (performance-critical, WASM)

# Contributing

See [Contributing Guide](docs/governance/CONTRIBUTING.adoc) and [Code of
Conduct](docs/governance/CODE_OF_CONDUCT.md).

- **Contribution Framework**: [TPCF Perimeter
  3](docs/governance/TPCF.md) (Community Sandbox)

- **Standards Compliance**: [RSR 89% Bronze](docs/standards/RSR.md)

- **Security Policy**: [Security](docs/governance/SECURITY.md)

# Roadmap

## v2.1 (Q2 2026)

- [ ] Python API wrapper

- [ ] R package

- [ ] REST API server mode

- [ ] Advanced forecasting (ARIMA, exponential smoothing)

- [ ] Machine learning integration

## v2.2 (Q3 2026)

- [ ] Google Sheets support

- [ ] Web application (standalone)

- [ ] Mobile apps (Gossamer)

- [ ] Collaborative features

- [ ] Cloud sync for cache

## v3.0 (Q4 2026)

- [ ] Real-time streaming data

- [ ] Custom data source builder

- [ ] Visual dashboard builder

- [ ] Natural language queries

- [ ] AI-powered insights

## v4.0 (Q1 2027)

- [ ] Advanced ML models (time-series forecasting)

- [ ] Scenario analysis and modeling

- [ ] Monte Carlo simulations

- [ ] Risk assessment tools

- [ ] Economic impact modeling

## v5.0 (Q2 2027) - Enterprise

- [ ] SSO/SAML authentication

- [ ] Audit logging and compliance

- [ ] Role-based access control (RBAC)

- [ ] Data governance features

- [ ] SLA monitoring and alerting

## v6.0 (Q3 2027) - Internationalization

- [ ] Multi-language interface support

- [ ] Localized economic indicators

- [ ] Regional data sources

- [ ] Currency conversion utilities

- [ ] Cultural customization

## v7.0 (Q4 2027) - Visualization

- [ ] Interactive charting engine

- [ ] Heatmaps and geographic visualizations

- [ ] Custom dashboard templates

- [ ] Report generation (PDF, PowerPoint)

- [ ] Data storytelling tools

## v8.0 (Q1 2028) - Collaboration

- [ ] Real-time co-editing

- [ ] Commenting and annotations

- [ ] Version control for models

- [ ] Team workspaces

- [ ] Shared data libraries

## v9.0 (Q2 2028) - Extensibility

- [ ] Plugin architecture

- [ ] Custom function SDK

- [ ] Third-party marketplace

- [ ] Webhook integrations

- [ ] GraphQL API

## v10.0 (Q3 2028) - Platform Maturity

- [ ] Governance council

- [ ] Certification program

- [ ] Academic partnerships

- [ ] Open standard for economic add-ins

- [ ] Community-driven development model

# License

This project is licensed under the **MPL-2.0** (MPL-2.0 License v1.0 or
later).

See [LICENSE](LICENSE) for full text and [palimpsest-license
repo](https://github.com/hyperpolymath/palimpsest-license) for
specifications.

Key provisions:

- File-level copyleft (based on MPL-2.0)

- Ethical use requirements

- Quantum-safe provenance support

- Emotional lineage preservation

# Support

- **Repository**:
  <https://github.com/hyperpolymath/excel-economic-numbers-tool>

- **Issues**:
  <https://github.com/hyperpolymath/excel-economic-numbers-tool/issues>

- **Discussions**:
  <https://github.com/hyperpolymath/excel-economic-numbers-tool/discussions>

------------------------------------------------------------------------

**Last updated:** 2026-01-23

# Architecture

See <a href="TOPOLOGY.md" class="md">TOPOLOGY</a> for a visual
architecture map and completion dashboard.
