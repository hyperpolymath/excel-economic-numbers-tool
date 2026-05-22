<!-- SPDX-License-Identifier: MPL-2.0 -->
<!-- TOPOLOGY.md — Project architecture map and completion dashboard -->
<!-- Last updated: 2026-02-19 -->

# Excel Economic Toolkit — Project Topology

## System Architecture

```
                        ┌─────────────────────────────────────────┐
                        │              EXCEL / CALC USERS         │
                        │        (Custom Spreadsheet Functions)   │
                        └──────────┬───────────────────┬──────────┘
                                   │                   │
                                   ▼                   ▼
                        ┌───────────────────┐  ┌───────────────────┐
                        │ EXCEL ADD-IN      │  │ LIBREOFFICE EXT   │
                        │ (Office.js / PWA) │  │ (UNO API / Python)│
                        └──────────┬────────┘  └──────────┬────────┘
                                   │                      │
                                   └──────────┬───────────┘
                                              │
                                              ▼
                        ┌─────────────────────────────────────────┐
                        │           APPLICATION LAYER             │
                        │    (ReScript, Logic, API Orchestration) │
                        └──────────┬───────────────────┬──────────┘
                                   │                   │
                                   ▼                   ▼
                        ┌───────────────────────┐  ┌────────────────────────────────┐
                        │ COMPUTATIONAL BACKEND │  │ INTELLIGENT CACHE              │
                        │ (Julia, Econometrics) │  │ (SQLite, Configurable TTL)     │
                        └──────────┬────────────┘  └────────────────────────────────┘
                                   │
                                   ▼
                        ┌─────────────────────────────────────────┐
                        │          EXTERNAL DATA SOURCES          │
                        │ (FRED, World Bank, IMF, OECD, ECB, BEA, │
                        │  Census, Eurostat, BIS, DBnomics)       │
                        └─────────────────────────────────────────┘

                        ┌─────────────────────────────────────────┐
                        │          REPO INFRASTRUCTURE            │
                        │  Justfile           .machine_readable/  │
                        │  Deno Tooling       RSR Bronze (89%)    │
                        └─────────────────────────────────────────┘
```

## Completion Dashboard

```
COMPONENT                          STATUS              NOTES
─────────────────────────────────  ──────────────────  ─────────────────────────────────
USER INTERFACES
  Excel Add-in (Office.js)          ██████████ 100%    v10.0 release stable
  LibreOffice (.oxt)                ██████████ 100%    UNO API integration active
  Navigation Guide                  ██████████ 100%    NAVIGATION.adoc verified

CORE & BACKEND
  ReScript Application Logic        ██████████ 100%    Type-safe core stable
  Julia Computational Backend       ██████████ 100%    Economic functions verified
  SQLite Caching                    ██████████ 100%    Persistent data verified
  Rate Limiting / Quotas            ██████████ 100%    API respect verified

DATA SOURCES
  Top 10 Sources (FRED, WB, etc)    ██████████ 100%    All connectors active
  API Key Management                ██████████ 100%    Secure config verified

REPO INFRASTRUCTURE
  Justfile (.build/ directory)      ██████████ 100%    Multi-platform build stable
  .machine_readable/                ██████████ 100%    STATE.a2ml tracking
  Comprehensive Tests               ██████████ 100%    High ReScript/Julia coverage

─────────────────────────────────────────────────────────────────────────────
OVERALL:                            ██████████ 100%    v10.0 Production Ready
```

## Key Dependencies

```
External API ───► Julia Backend ───► ReScript Core ───► Office.js
     │                 │                 │                 │
     ▼                 ▼                 ▼                 ▼
Rate Limiter ─────► SQLite Cache ──────► Function Map ──► Spreadsheet
```

## Update Protocol

This file is maintained by both humans and AI agents. When updating:

1. **After completing a component**: Change its bar and percentage
2. **After adding a component**: Add a new row in the appropriate section
3. **After architectural changes**: Update the ASCII diagram
4. **Date**: Update the `Last updated` comment at the top of this file

Progress bars use: `█` (filled) and `░` (empty), 10 characters wide.
Percentages: 0%, 10%, 20%, ... 100% (in 10% increments).
