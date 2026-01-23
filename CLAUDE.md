# Economic Toolkit v2.0 - Project Documentation

## Project Summary

Modular Excel/LibreOffice Add-in for economic modelling and investigative research. Provides 10+ free data sources (FRED, World Bank, IMF, etc.), custom economic formulas, constraint propagation, and literate programming. Cross-platform architecture supports Microsoft Excel (Office.js) and LibreOffice Calc (UNO API) from single codebase.

## Architecture Overview

### Core Design Principles

1. **Cross-Platform Abstraction**: Single `ISpreadsheetAdapter` interface with platform-specific adapters
2. **Julia Backend**: High-performance computation engine with HTTP/QUIC API
3. **Type Safety**: TypeScript/ReScript for UI, Julia for backend
4. **Production-Grade Reliability**: Caching, rate limiting, exponential backoff retry
5. **Offline Capability**: SQLite cache survives restarts

### Technology Stack

- **Backend**: Julia ≥1.10 (computation, data sources)
- **Frontend**: TypeScript/ReScript (UI components)
- **Excel Integration**: Office.js API
- **LibreOffice Integration**: UNO API (Rhino JS)
- **Containerization**: Podman ≥4.0
- **Build System**: Just ≥1.0
- **CI/CD**: GitLab (6 stages: lint, test, build, security, deploy, release)

## Project Structure

```
economic-toolkit-v2/
├── src/
│   ├── julia/                      # Julia backend
│   │   ├── EconomicToolkit.jl     # Main module
│   │   ├── data_sources/          # Data source clients
│   │   │   ├── FRED.jl
│   │   │   ├── WorldBank.jl
│   │   │   ├── IMF.jl
│   │   │   ├── OECD.jl
│   │   │   ├── DBnomics.jl
│   │   │   ├── ECB.jl
│   │   │   ├── BEA.jl
│   │   │   ├── Census.jl
│   │   │   ├── Eurostat.jl
│   │   │   └── BIS.jl
│   │   ├── formulas/              # Economic formulas
│   │   │   ├── elasticity.jl
│   │   │   ├── gdp_growth.jl
│   │   │   ├── lorenz.jl
│   │   │   └── constraints.jl
│   │   ├── cache/                 # Caching infrastructure
│   │   │   └── sqlite_cache.jl
│   │   └── utils/                 # Rate limiting, retry logic
│   │       ├── rate_limiter.jl
│   │       └── retry.jl
│   ├── typescript/                # TypeScript adapters
│   │   ├── adapters/
│   │   │   ├── ISpreadsheetAdapter.ts
│   │   │   ├── OfficeJsAdapter.ts
│   │   │   └── UnoAdapter.js      # Rhino JS for LibreOffice
│   │   └── utils/
│   └── rescript/                  # ReScript UI
│       ├── ribbons/               # Ribbon tabs
│       └── taskpanes/             # Task panes
├── tests/
│   ├── julia/                     # Julia tests
│   ├── typescript/                # TypeScript tests
│   └── integration/               # Integration tests
├── docs/
│   ├── architecture.md
│   ├── data_sources.md
│   ├── api_reference.md
│   └── contributing.md
├── dist/
│   ├── officejs/                  # Excel deployment
│   │   └── manifest.xml
│   └── uno/                       # LibreOffice deployment
│       └── economic-toolkit.oxt
├── .gitlab-ci.yml                 # CI/CD pipeline
├── Justfile                       # Build automation
├── bootstrap.sh                   # Dependency checker
├── Project.toml                   # Julia dependencies
├── package.json                   # Node dependencies
└── README.md
```

## Data Sources (10+ Free Sources)

### Implemented

1. **FRED** (Federal Reserve Economic Data)
   - Rate limit: 120 requests/minute
   - API key: Optional (higher limits with key)
   - Coverage: US economic indicators, 800K+ series

2. **World Bank**
   - Rate limit: 60 requests/minute
   - API key: Not required
   - Coverage: Global development indicators, 16K+ series

### High Priority (To Implement)

3. **IMF** (International Monetary Fund)
   - Rate limit: 60 requests/minute
   - API key: Not required
   - Coverage: International financial statistics

4. **OECD** (Organisation for Economic Co-operation and Development)
   - Rate limit: 60 requests/minute
   - API key: Not required
   - Coverage: OECD member countries

5. **DBnomics** (Data aggregator)
   - Rate limit: 500 requests/minute
   - API key: Not required
   - Coverage: 70+ data providers including BIS

6. **ECB** (European Central Bank)
   - Rate limit: 60 requests/minute
   - API key: Not required
   - Coverage: Eurozone monetary and financial data

### Lower Priority (Stubs)

7. **BEA** (Bureau of Economic Analysis)
   - API key: Optional
   - Coverage: US GDP, trade, industry data

8. **Census Bureau**
   - API key: Optional
   - Coverage: US demographic and economic census

9. **Eurostat**
   - Rate limit: 60 requests/minute
   - Coverage: EU statistical data

10. **BIS** (Bank for International Settlements)
    - Rate limit: 60 requests/minute
    - Coverage: International banking statistics

## Data Source Pattern

Each data source client follows this pattern:

```julia
struct <Name>Client
    base_url::String
    api_key::Union{String, Nothing}
    rate_limiter::RateLimiter
    cache::SQLiteCache
end

function fetch_series(client::<Name>Client, series_id::String, start_date::Date, end_date::Date)
    # 1. Check cache
    # 2. Rate limit
    # 3. HTTP request with retry logic
    # 4. Parse response
    # 5. Cache result
    # 6. Return data
end

function search_series(client::<Name>Client, query::String)
    # Search functionality
end
```

## Caching System

- **Storage**: SQLite database per source at `~/.economic-toolkit/cache/data.db`
- **Key**: `hash(source + series + start_date + end_date)`
- **TTL**: Configurable per source (default: 24 hours)
- **Fallback**: On network failure, returns cached data if available

## Rate Limiting

- **Algorithm**: Sliding window (60-second window)
- **Per-Source Limits**:
  - FRED: 120/min
  - DBnomics: 500/min
  - Others: 60/min
- **Behavior**: Sleeps if limit exceeded, doesn't error

## Retry Logic

- **Exponential Backoff**: 2s → 4s → 8s
- **Max Retries**: 3
- **Fallback**: Returns cached data on final failure
- **Error Types**: Network errors, timeouts, rate limits (429)

## Cross-Platform Adapter System

### ISpreadsheetAdapter Interface

```typescript
interface ISpreadsheetAdapter {
    // Cell operations
    getCellValue(address: string): any;
    setCellValue(address: string, value: any): void;
    getRange(start: string, end: string): any[][];
    setRange(start: string, data: any[][]): void;

    // Custom functions
    registerFunction(name: string, fn: Function): void;

    // Events
    onSelectionChange(handler: Function): void;
    onCalculate(handler: Function): void;

    // UI
    showDialog(title: string, content: string): void;
    showTaskPane(component: string): void;
}
```

### Platform Detection

```typescript
function createAdapter(): ISpreadsheetAdapter {
    if (typeof Office !== 'undefined') {
        return new OfficeJsAdapter();
    } else if (typeof XSCRIPTCONTEXT !== 'undefined') {
        return new UnoAdapter();
    } else {
        throw new Error('Unknown platform');
    }
}
```

### Platform-Specific Notes

**Office.js (Excel)**:
- Modern ES6+ JavaScript
- Custom functions require manifest registration
- Async/await supported
- Rich event system

**UNO (LibreOffice)**:
- Rhino JavaScript (Java-style, ES5-ish)
- No native async/await (use Java threads)
- Different event model
- Access to Java classes via importClass()

## Economic Formulas

### Implemented (To Complete)

1. **Elasticity Calculations**
   - Price elasticity of demand
   - Income elasticity
   - Cross-price elasticity

2. **GDP Growth**
   - YoY (Year-over-Year)
   - QoQ (Quarter-over-Quarter)
   - MoM (Month-over-Month)
   - CAGR (Compound Annual Growth Rate)

3. **Lorenz Curve & Gini Coefficient**
   - Income inequality measures
   - Wealth distribution analysis

4. **Constraint Propagation**
   - Equation system solver
   - Identity enforcement (e.g., C + I + G + NX = GDP)
   - Literate programming support

## ReScript UI Components

### Ribbon Tabs (5)

1. **Data** - Data source selection and import
2. **Formulas** - Economic formula insertion
3. **Analysis** - Statistical and econometric tools
4. **Constraints** - Constraint system management
5. **Help** - Documentation and support

### Task Panes (4)

1. **Data Browser** - Search and preview data series
2. **Formula Builder** - Visual formula construction
3. **Constraint Editor** - Define and manage constraints
4. **Settings** - API keys, cache settings, preferences

## Build & Deployment

### Development Workflow

```bash
# Check dependencies
./bootstrap.sh

# Development
just dev          # Start dev servers
just test         # Run tests
just lint         # Lint code

# Build
just build        # Build all platforms
just build-excel  # Build Excel add-in only
just build-libre  # Build LibreOffice extension only

# Deploy
just deploy       # Deploy to local testing
```

### CI/CD Pipeline (6 Stages)

1. **Lint**: ESLint, Julia formatter
2. **Test**: Unit tests, integration tests (95%+ coverage target)
3. **Build**: Compile TypeScript, package manifests
4. **Security**: Dependency scanning, SAST
5. **Deploy**: Push to container registry
6. **Release**: Create GitLab releases, publish artifacts

### Artifacts

- `dist/officejs/manifest.xml` + compiled JS
- `dist/uno/economic-toolkit.oxt` (LibreOffice extension)
- Container image: `registry.gitlab.com/hyperpolymath/economic-toolkit`

## Installation & Setup

### Prerequisites

- Julia ≥1.10
- Node.js ≥20
- Podman ≥4.0
- Git ≥2.30
- Just ≥1.0

### Quick Start

```bash
# Clone repository
git clone https://github.com/Hyperpolymath/excel-economic-number-tool-.git
cd excel-economic-number-tool-

# Check dependencies
./bootstrap.sh

# Install dependencies
just install

# Run tests
just test

# Build
just build

# Install Excel add-in
just install-excel

# Install LibreOffice extension
just install-libre
```

## API Reference

### Julia Backend API

HTTP/QUIC server endpoints:

```
GET  /api/v1/sources                    # List available data sources
GET  /api/v1/sources/{source}/search    # Search series
GET  /api/v1/sources/{source}/series    # Fetch series data
POST /api/v1/formulas/{formula}         # Execute formula
POST /api/v1/constraints/solve          # Solve constraint system
GET  /api/v1/cache/stats                # Cache statistics
```

### Spreadsheet Functions

**Data Functions**:
- `=ECON.FRED("GDPC1", start, end)` - Fetch FRED series
- `=ECON.WB("NY.GDP.MKTP.CD", "USA", start, end)` - World Bank data
- `=ECON.SEARCH("GDP", "FRED")` - Search data series

**Economic Formulas**:
- `=ECON.ELASTICITY(prices, quantities)` - Calculate elasticity
- `=ECON.GROWTH(series, "YoY")` - Growth rate
- `=ECON.GINI(distribution)` - Gini coefficient

**Constraint System**:
- `=ECON.CONSTRAIN(equation, variables)` - Define constraint
- `=ECON.SOLVE()` - Solve constraint system

## Development Guidelines

### Code Style

- **Julia**: Follow Blue style guide
- **TypeScript**: ESLint + Prettier
- **ReScript**: Standard ReScript formatter

### Testing Requirements

- Unit test coverage: ≥95%
- Integration tests for all data sources
- E2E tests for both Excel and LibreOffice
- Performance tests for large datasets (1M+ rows)

### Data Handling Best Practices

1. **Always validate inputs**: Check date ranges, series IDs
2. **Handle errors gracefully**: Return cached data on failure
3. **Preserve precision**: Use Decimal types for financial data
4. **Cache aggressively**: Reduce API calls
5. **Rate limit defensively**: Stay well below API limits

### Performance Optimization

- Stream large datasets (don't load into memory)
- Use lazy evaluation for formula chains
- Batch API requests when possible
- Profile hot paths in Julia backend

## Known Limitations

1. **Custom Functions**: Excel requires manifest registration, can't be purely dynamic
2. **LibreOffice UNO**: Limited to ES5-style JavaScript (Rhino engine)
3. **Offline Mode**: Limited to cached data only
4. **Rate Limits**: Free tier API limits may restrict heavy usage
5. **Data Latency**: Economic data typically updated monthly/quarterly

## Future Enhancements

### Short-term (v2.1)

- [ ] Add more data sources (15+ total)
- [ ] Implement data visualization components
- [ ] Add export to multiple formats (CSV, JSON, Parquet)
- [ ] Implement data transformation pipeline

### Medium-term (v2.5)

- [ ] Web-based version (WASM + Julia HTTP server)
- [ ] Real-time data streaming
- [ ] Collaborative features (shared constraints)
- [ ] Advanced econometric models (VAR, VECM, GARCH)

### Long-term (v3.0)

- [ ] Machine learning integration
- [ ] Natural language query interface
- [ ] Automated report generation
- [ ] Multi-language support (i18n)

## Contributing

### Contribution Workflow

1. Fork repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Implement changes with tests
4. Ensure 95%+ test coverage
5. Run linter (`just lint`)
6. Commit with conventional commits
7. Push and create pull request

### Commit Message Format

```
type(scope): subject

body

footer
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

## Resources

### Economic Data Standards

- **ISO 4217**: Currency codes
- **ISO 3166**: Country codes
- **SNA 2008**: System of National Accounts
- **SDMX**: Statistical Data and Metadata eXchange

### Data Source Documentation

- [FRED API](https://fred.stlouisfed.org/docs/api/)
- [World Bank API](https://datahelpdesk.worldbank.org/knowledgebase/articles/889392)
- [IMF API](https://datahelp.imf.org/knowledgebase/articles/667681)
- [OECD API](https://data.oecd.org/api/)
- [DBnomics API](https://api.db.nomics.world/)

### Technical References

- [Office.js API](https://learn.microsoft.com/en-us/office/dev/add-ins/)
- [LibreOffice UNO](https://api.libreoffice.org/)
- [Julia Performance Tips](https://docs.julialang.org/en/v1/manual/performance-tips/)

## License

MIT License - See LICENSE file for details

## Contact

- Repository: https://github.com/Hyperpolymath/excel-economic-number-tool-
- Issues: https://github.com/Hyperpolymath/excel-economic-number-tool-/issues
- Discussions: https://github.com/Hyperpolymath/excel-economic-number-tool-/discussions

## Project Status

**Current Phase**: Active Development
**Target MVP**: 4-6 weeks
**Test Coverage**: Target 95%+
**Supported Platforms**: Microsoft Excel 2016+, LibreOffice Calc 7.0+

---

*Last Updated: 2025-11-22*
*Version: 2.0.0-dev*
