# Developer Guide - Economic Toolkit v2.0

## Table of Contents

1. [Getting Started](#getting-started)
2. [Project Architecture](#project-architecture)
3. [Development Workflow](#development-workflow)
4. [Adding Data Sources](#adding-data-sources)
5. [Adding Economic Formulas](#adding-economic-formulas)
6. [Testing](#testing)
7. [Building and Deployment](#building-and-deployment)
8. [Troubleshooting](#troubleshooting)

---

## Getting Started

### Prerequisites

Ensure you have all required dependencies:

```bash
# Check dependencies
./bootstrap.sh
```

Required versions:
- Julia ≥1.10
- Node.js ≥20
- Git ≥2.30
- Just ≥1.0 (optional but recommended)
- Podman ≥4.0 (optional, for containers)

### Initial Setup

```bash
# Clone repository
git clone https://github.com/Hyperpolymath/excel-economic-number-tool-.git
cd excel-economic-number-tool-

# Install dependencies
just install
# or manually:
julia --project=. -e 'using Pkg; Pkg.instantiate()'
npm install

# Run tests to verify setup
just test

# Start development server
just dev
```

---

## Project Architecture

### Directory Structure

```
economic-toolkit-v2/
├── src/
│   ├── julia/              # Julia backend
│   │   ├── EconomicToolkit.jl  # Main module
│   │   ├── data_sources/       # Data source clients
│   │   ├── formulas/           # Economic formulas
│   │   ├── cache/              # Caching infrastructure
│   │   └── utils/              # Utilities (rate limiting, retry)
│   ├── typescript/         # TypeScript frontend
│   │   ├── adapters/       # Platform adapters
│   │   └── utils/          # Utilities
│   └── rescript/           # ReScript UI components
│       ├── ribbons/        # Ribbon tabs
│       └── taskpanes/      # Task panes
├── tests/                  # Test suites
│   ├── julia/              # Julia tests
│   ├── typescript/         # TypeScript tests
│   └── integration/        # Integration tests
├── docs/                   # Documentation
├── examples/               # Usage examples
└── dist/                   # Build outputs (gitignored)
```

### Component Interaction

```
┌─────────────────────────────────────────────────────┐
│                  Spreadsheet                        │
│        (Excel / LibreOffice Calc)                   │
└─────────────────────────────────────────────────────┘
                      ↑ ↓
┌─────────────────────────────────────────────────────┐
│           Platform Adapter Layer                    │
│  ┌─────────────────┐    ┌────────────────────────┐ │
│  │ OfficeJsAdapter │    │    UnoAdapter          │ │
│  │   (Excel)       │    │   (LibreOffice)        │ │
│  └─────────────────┘    └────────────────────────┘ │
└─────────────────────────────────────────────────────┘
                      ↑ ↓ HTTP/QUIC
┌─────────────────────────────────────────────────────┐
│              Julia Backend Server                   │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────┐ │
│  │ Data Sources │  │   Formulas   │  │ Cache     │ │
│  │  (10+)       │  │ (Elasticity, │  │ (SQLite)  │ │
│  │              │  │  Growth,etc) │  │           │ │
│  └──────────────┘  └──────────────┘  └───────────┘ │
└─────────────────────────────────────────────────────┘
                      ↑ ↓ HTTP APIs
┌─────────────────────────────────────────────────────┐
│          External Data Sources                      │
│  FRED │ World Bank │ IMF │ OECD │ DBnomics │ etc   │
└─────────────────────────────────────────────────────┘
```

---

## Development Workflow

### Daily Development

```bash
# 1. Start development servers
just dev
# This starts:
# - Julia backend on port 8080
# - Webpack dev server on port 3000

# 2. Make changes to code

# 3. Run tests
just test

# 4. Lint code
just lint

# 5. Build
just build
```

### Git Workflow

```bash
# 1. Create feature branch
git checkout -b feature/my-feature

# 2. Make changes and commit
git add .
git commit -m "feat: add new feature"

# 3. Run pre-commit checks
just pre-commit

# 4. Push and create PR
git push origin feature/my-feature
```

### Code Style

#### Julia

Follow Blue style guide:

```julia
# Good
function fetch_series(client::FREDClient, series_id::String,
                     start_date::Date, end_date::Date)::DataFrame
    # Implementation
end

# Bad
function fetch_series(client::FREDClient,series_id::String,start_date::Date,end_date::Date)::DataFrame
    # Implementation
end
```

Auto-format:
```bash
just lint-fix-julia
```

#### TypeScript

Use ESLint + Prettier:

```typescript
// Good
export interface ISpreadsheetAdapter {
  getCellValue(address: string): Promise<CellValue>;
}

// Bad
export interface ISpreadsheetAdapter{
    getCellValue(address:string):Promise<CellValue>
}
```

Auto-format:
```bash
just lint-fix-typescript
```

---

## Adding Data Sources

### Step-by-Step Guide

#### 1. Create Client File

Create `src/julia/data_sources/MySource.jl`:

```julia
"""
MySource Client

API Documentation: https://api.mysource.org/docs
Rate Limit: 60 requests/minute
API Key: Not required
"""

using HTTP
using JSON3
using Dates

struct MySourceClient
    base_url::String
    rate_limiter::RateLimiter
    cache::SQLiteCache
    retry_config::RetryConfig

    function MySourceClient(; cache_ttl::Int=86400)
        base_url = "https://api.mysource.org/v1"
        rate_limiter = RateLimiter(60)
        cache = SQLiteCache(default_ttl=cache_ttl)
        retry_config = RetryConfig()

        new(base_url, rate_limiter, cache, retry_config)
    end
end

function fetch_series(client::MySourceClient, series_id::String,
                     start_date::Date, end_date::Date)::DataFrame
    # Check cache
    key = cache_key("mysource", series_id, start_date, end_date)
    cached = get_cached(client.cache, key)

    if cached !== nothing
        return JSON3.read(cached, DataFrame)
    end

    # Rate limit
    wait_if_needed(client.rate_limiter)

    # Fetch data
    function fetch()
        url = "$(client.base_url)/series/$(series_id)"
        params = Dict(
            "start" => Dates.format(start_date, "yyyy-mm-dd"),
            "end" => Dates.format(end_date, "yyyy-mm-dd")
        )

        response = HTTP.get(url, query=params)
        return response.body
    end

    # Execute with retry
    body, from_cache = with_retry_and_cache(fetch, client.cache, key,
                                            client.retry_config)

    if !from_cache
        # Parse and cache
        data = JSON3.read(body)
        df = DataFrame(date=data.dates, value=data.values)

        set_cached(client.cache, key, JSON3.write(df),
                  metadata=Dict("source" => "mysource",
                               "series_id" => series_id))

        return df
    else
        return body
    end
end

function search_series(client::MySourceClient, query::String;
                      limit::Int=100)::Vector{Dict}
    # Implementation similar to fetch_series
    # ...
end
```

#### 2. Register in Main Module

Edit `src/julia/EconomicToolkit.jl`:

```julia
# Add to includes
include("data_sources/MySource.jl")

# Add to exports
export MySourceClient

# Add to server client list
clients = Dict(
    "fred" => fred,
    "worldbank" => wb,
    "mysource" => MySourceClient(),  # Add here
    # ...
)
```

#### 3. Write Tests

Create `tests/julia/test_mysource.jl`:

```julia
using Test

include("../../src/julia/data_sources/MySource.jl")

@testset "MySource Tests" begin
    @testset "Client Creation" begin
        client = MySourceClient()
        @test client.base_url == "https://api.mysource.org/v1"
    end

    @testset "Fetch Series" begin
        client = MySourceClient()

        # Mock data
        # ... (use mocking library or skip if API key required)
    end
end
```

#### 4. Update Documentation

- Add to `docs/data_sources.md`
- Add examples to `examples/`
- Update `README.md`

#### 5. Test End-to-End

```bash
# Run specific test
julia --project=. tests/julia/test_mysource.jl

# Run all tests
just test
```

---

## Adding Economic Formulas

### Step-by-Step Guide

#### 1. Create Formula File

Create `src/julia/formulas/my_formula.jl`:

```julia
"""
My Formula Module

Calculates something useful for economists.
"""

using Statistics

"""
    my_formula(data::Vector{Float64}; param::Float64=1.0)::Float64

Calculate my formula on data.

# Arguments
- `data::Vector{Float64}`: Input data
- `param::Float64`: Parameter (default: 1.0)

# Returns
- `Float64`: Calculated result

# Example
```julia
data = [1.0, 2.0, 3.0, 4.0, 5.0]
result = my_formula(data, param=2.0)
```
"""
function my_formula(data::Vector{Float64}; param::Float64=1.0)::Float64
    if isempty(data)
        throw(ArgumentError("Data cannot be empty"))
    end

    # Your calculation
    result = mean(data) * param

    return result
end
```

#### 2. Register in Main Module

Edit `src/julia/EconomicToolkit.jl`:

```julia
# Add include
include("formulas/my_formula.jl")

# Add export
export my_formula
```

#### 3. Write Tests

Create `tests/julia/test_my_formula.jl`:

```julia
using Test

include("../../src/julia/formulas/my_formula.jl")

@testset "My Formula Tests" begin
    @testset "Basic Calculation" begin
        data = [2.0, 4.0, 6.0, 8.0]
        result = my_formula(data, param=2.0)

        expected = mean(data) * 2.0
        @test result ≈ expected
    end

    @testset "Edge Cases" begin
        # Empty data
        @test_throws ArgumentError my_formula([])

        # Single value
        result = my_formula([5.0])
        @test result ≈ 5.0
    end
end
```

#### 4. Add to TypeScript Adapter

Edit `src/typescript/adapters/OfficeJsAdapter.ts` or create wrapper:

```typescript
// Register spreadsheet function
adapter.registerFunction({
    name: 'ECON.MYFORMULA',
    description: 'Calculate my formula',
    parameters: [
        {
            name: 'data',
            description: 'Data range',
            type: 'range'
        },
        {
            name: 'param',
            description: 'Parameter value',
            type: 'number'
        }
    ],
    returnType: 'number'
}, async (data, param = 1.0) => {
    // Call Julia backend
    const response = await fetch('http://localhost:8080/api/v1/formulas/myformula', {
        method: 'POST',
        body: JSON.stringify({ data, param })
    });
    return await response.json();
});
```

#### 5. Add API Endpoint

Edit `src/julia/EconomicToolkit.jl`:

```julia
# Add to router
HTTP.register!(router, "POST", "/api/v1/formulas/myformula") do req
    body = JSON3.read(req.body)
    data = body.data
    param = get(body, :param, 1.0)

    result = my_formula(data, param=param)

    return HTTP.Response(200, JSON3.write(Dict("result" => result)))
end
```

---

## Testing

### Running Tests

```bash
# All tests
just test

# Julia tests only
just test-julia

# TypeScript tests only
just test-typescript

# With coverage
just test-coverage

# Specific test file
julia --project=. tests/julia/test_my_formula.jl
```

### Writing Good Tests

```julia
@testset "Feature Name" begin
    @testset "Normal Cases" begin
        # Test typical usage
        result = my_function(normal_input)
        @test result ≈ expected_output
    end

    @testset "Edge Cases" begin
        # Test boundaries
        @test my_function([]) throws ArgumentError
        @test my_function([1.0]) == 1.0
    end

    @testset "Error Handling" begin
        # Test error conditions
        @test_throws DomainError my_function(-1.0)
    end
end
```

### Coverage Requirements

- Target: ≥95% code coverage
- All public functions must have tests
- Test both success and failure paths
- Test edge cases

---

## Building and Deployment

### Local Build

```bash
# Full build
just build

# Build specific targets
just build-excel      # Excel add-in
just build-libre      # LibreOffice extension
just build-julia      # Julia sysimage
```

### Deployment

```bash
# Run deployment script
just deploy
# or
./deploy.sh

# This will:
# 1. Run tests
# 2. Build all targets
# 3. Create deployment artifacts
```

### Container Build

```bash
# Build container
podman build -t economic-toolkit:latest -f Containerfile .

# Run container
podman run -p 8080:8080 economic-toolkit:latest

# Test
curl http://localhost:8080/health
```

---

## Troubleshooting

### Common Issues

#### Julia Package Issues

```bash
# Clear and reinstall
rm -rf ~/.julia
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

#### Node Modules Issues

```bash
# Clear and reinstall
rm -rf node_modules package-lock.json
npm install
```

#### Port Already in Use

```bash
# Find and kill process on port 8080
lsof -ti:8080 | xargs kill -9

# Or use different port
julia --project=. -e 'using EconomicToolkit; start_server(8081)'
```

#### Cache Issues

```julia
using EconomicToolkit
client = FREDClient()
clear_all(client.cache)  # Clear all cached data
```

### Debug Mode

```bash
# Julia with debug output
JULIA_DEBUG=all julia --project=. src/julia/EconomicToolkit.jl --dev

# TypeScript with source maps
npm run dev  # Enables source maps
```

### Getting Help

1. Check documentation in `docs/`
2. Search existing issues on GitHub
3. Create new issue with:
   - OS and versions
   - Steps to reproduce
   - Error messages
   - Minimal code example

---

## Performance Optimization

### Julia

- Use `@inbounds` for array access when bounds are guaranteed
- Avoid global variables
- Use type annotations
- Pre-allocate arrays when possible

```julia
# Good
function process_data(data::Vector{Float64})::Vector{Float64}
    result = similar(data)  # Pre-allocate
    @inbounds for i in eachindex(data)
        result[i] = data[i] * 2.0
    end
    return result
end

# Bad
result = []
for x in data
    push!(result, x * 2.0)
end
```

### TypeScript

- Use batch operations for multiple cell updates
- Minimize cross-origin calls
- Cache frequently accessed data

```typescript
// Good - batch operations
await adapter.batch(async () => {
    await adapter.setCellValue("A1", 1);
    await adapter.setCellValue("A2", 2);
    await adapter.setCellValue("A3", 3);
});

// Bad - individual calls
await adapter.setCellValue("A1", 1);
await adapter.setCellValue("A2", 2);
await adapter.setCellValue("A3", 3);
```

---

## Best Practices

1. **Documentation**: Document all public APIs
2. **Testing**: Write tests before or alongside code
3. **Error Handling**: Always handle errors gracefully
4. **Performance**: Profile before optimizing
5. **Security**: Never commit API keys or secrets
6. **Versioning**: Use semantic versioning
7. **Code Review**: All changes go through PR review

---

## Resources

- [Julia Documentation](https://docs.julialang.org/)
- [TypeScript Handbook](https://www.typescriptlang.org/docs/)
- [Office.js API](https://learn.microsoft.com/en-us/office/dev/add-ins/)
- [LibreOffice UNO](https://api.libreoffice.org/)
- [Project Issues](https://github.com/Hyperpolymath/excel-economic-number-tool-/issues)

---

**Happy Coding! 🚀**
