<!--
SPDX-License-Identifier: MPL-2.0
Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-->
# TEST-NEEDS.md — excel-economic-numbers-tool

## CRG Grade: C — ACHIEVED 2026-04-04

## Current Test State

| Category | Count | Notes |
|----------|-------|-------|
| Test files | 8 | Current state |

## What's Covered

- [x] 8 existing test file(s)
- [x] Zig FFI integration tests
- [x] Julia test suite

## Still Missing (for CRG B+)

- [ ] CI/CD test automation
- [ ] Property-based tests
- [ ] Edge case coverage

## Run Tests

```bash
cd tests && julia runtests.jl
```
