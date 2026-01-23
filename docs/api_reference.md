# API Reference - Economic Toolkit v2.0

## Table of Contents

1. [Julia Backend API](#julia-backend-api)
2. [Data Source APIs](#data-source-apis)
3. [Formula APIs](#formula-apis)
4. [Spreadsheet Functions](#spreadsheet-functions)
5. [TypeScript Adapter API](#typescript-adapter-api)

---

## Julia Backend API

### HTTP Server

The Julia backend exposes a REST API on port 8080.

#### Start Server

```julia
using EconomicToolkit

# Start with default settings (port 8080)
start_server()

# Custom port
start_server(8081, host="0.0.0.0")
```

### Endpoints

#### GET /health

Health check endpoint.

**Response:**
```json
{
  "status": "ok",
  "version": "2.0.0"
}
```

#### GET /api/v1/sources

List all available data sources.

**Response:**
```json
[
  {
    "id": "fred",
    "name": "Federal Reserve Economic Data",
    "status": "active"
  },
  {
    "id": "worldbank",
    "name": "World Bank",
    "status": "active"
  }
]
```

#### GET /api/v1/sources/:source/search

Search for series in a data source.

**Parameters:**
- `q` (query string): Search query

**Example:**
```
GET /api/v1/sources/fred/search?q=GDP
```

**Response:**
```json
[
  {
    "id": "GDPC1",
    "title": "Real Gross Domestic Product",
    "frequency": "Quarterly",
    "units": "Billions of Chained 2012 Dollars",
    "seasonal_adjustment": "Seasonally Adjusted Annual Rate"
  }
]
```

#### GET /api/v1/sources/:source/series/:id

Fetch time series data.

**Parameters:**
- `start` (optional): Start date (YYYY-MM-DD)
- `end` (optional): End date (YYYY-MM-DD)

**Example:**
```
GET /api/v1/sources/fred/series/GDPC1?start=2020-01-01&end=2023-12-31
```

**Response:**
```json
{
  "date": ["2020-01-01", "2020-04-01", "2020-07-01"],
  "value": [19032.1, 17302.5, 18596.5]
}
```

---

## Data Source APIs

### FRED Client

#### Constructor

```julia
client = FREDClient(api_key="your_api_key")
```

**Parameters:**
- `api_key`: Optional API key (increases rate limit from 5/min to 120/min)

#### fetch_series

```julia
data = fetch_series(client, series_id, start_date, end_date)
```

**Parameters:**
- `series_id::String`: FRED series ID (e.g., "GDPC1")
- `start_date::Date`: Start date
- `end_date::Date`: End date

**Returns:** `DataFrame` with columns `[:date, :value]`

**Example:**
```julia
using Dates
data = fetch_series(client, "GDPC1", Date(2020, 1, 1), Date(2023, 12, 31))
```

#### search_series

```julia
results = search_series(client, query; limit=100)
```

**Parameters:**
- `query::String`: Search query
- `limit::Int`: Maximum results (default: 100)

**Returns:** `Vector{Dict}` with series metadata

### World Bank Client

#### Constructor

```julia
client = WorldBankClient()
```

#### fetch_series

```julia
data = fetch_series(client, indicator_code, country_code, start_date, end_date)
```

**Parameters:**
- `indicator_code::String`: Indicator code (e.g., "NY.GDP.MKTP.CD")
- `country_code::String`: ISO 3-letter country code (e.g., "USA", "GBR")
- `start_date::Date`: Start date
- `end_date::Date`: End date

**Example:**
```julia
# Fetch GDP for USA
data = fetch_series(client, "NY.GDP.MKTP.CD", "USA", Date(2010, 1, 1), Date(2020, 12, 31))
```

---

## Formula APIs

### Elasticity

#### elasticity

Calculate price elasticity of demand.

```julia
ε = elasticity(quantities, prices; method=:midpoint)
```

**Parameters:**
- `quantities::Vector{Float64}`: Quantity values
- `prices::Vector{Float64}`: Price values
- `method::Symbol`: Calculation method (`:midpoint`, `:arc`, `:point`, `:log`)

**Returns:** `Float64` - Elasticity coefficient

**Methods:**
- `:midpoint` - Midpoint method (default): ε = (ΔQ/Q_avg) / (ΔP/P_avg)
- `:arc` - Arc elasticity (average across periods)
- `:point` - Point elasticity using regression
- `:log` - Log-log regression

**Example:**
```julia
prices = [10.0, 12.0, 14.0]
quantities = [100.0, 85.0, 70.0]
ε = elasticity(quantities, prices, method=:midpoint)
# Returns approximately -1.5 (elastic demand)
```

#### income_elasticity

```julia
ε_I = income_elasticity(quantities, incomes)
```

**Interpretation:**
- ε_I > 1: Luxury good
- 0 < ε_I < 1: Normal good
- ε_I < 0: Inferior good

#### cross_price_elasticity

```julia
ε_xy = cross_price_elasticity(quantities_x, prices_y)
```

**Interpretation:**
- ε_xy > 0: Substitute goods
- ε_xy < 0: Complementary goods
- ε_xy ≈ 0: Independent goods

### GDP Growth

#### gdp_growth

Calculate GDP growth rates.

```julia
growth = gdp_growth(values, dates; method=:yoy)
```

**Parameters:**
- `values::Vector{Float64}`: GDP values
- `dates::Vector{Date}`: Corresponding dates
- `method::Symbol`: Growth method (`:yoy`, `:qoq`, `:mom`, `:cagr`)

**Returns:** `Vector{Float64}` - Growth rates as percentages

**Methods:**
- `:yoy` - Year-over-Year
- `:qoq` - Quarter-over-Quarter (annualized)
- `:mom` - Month-over-Month (annualized)
- `:cagr` - Compound Annual Growth Rate

**Example:**
```julia
values = [20000.0, 21000.0, 22000.0]
dates = [Date(2021, 1, 1), Date(2022, 1, 1), Date(2023, 1, 1)]
growth = gdp_growth(values, dates, method=:yoy)
# Returns [NaN, 5.0, 4.76] (percentages)
```

#### real_growth

Adjust for inflation using GDP deflator.

```julia
real_values = real_growth(nominal_values, deflator)
```

**Parameters:**
- `nominal_values::Vector{Float64}`: Nominal GDP values
- `deflator::Vector{Float64}`: GDP deflator (base year = 100)

#### contribution_to_growth

Calculate component contribution to overall growth.

```julia
contribution = contribution_to_growth(component_values, total_values)
```

**Example:**
```julia
consumption = [14000.0, 14500.0, 15000.0]
gdp = [20000.0, 21000.0, 22000.0]
contribution = contribution_to_growth(consumption, gdp)
# Returns how much consumption contributed to GDP growth
```

### Inequality Measures

#### gini_coefficient

Calculate Gini coefficient of inequality.

```julia
gini = gini_coefficient(incomes)
```

**Parameters:**
- `incomes::Vector{Float64}`: Income distribution

**Returns:** `Float64` - Gini coefficient (0 = perfect equality, 1 = perfect inequality)

**Interpretation:**
- 0.0-0.3: Low inequality
- 0.3-0.4: Moderate inequality
- 0.4-0.5: High inequality
- 0.5+: Very high inequality

**Example:**
```julia
incomes = [10000.0, 20000.0, 30000.0, 50000.0, 100000.0]
gini = gini_coefficient(incomes)
# Returns approximately 0.36 (moderate inequality)
```

#### lorenz_curve

Calculate Lorenz curve coordinates.

```julia
pop_share, income_share = lorenz_curve(incomes)
```

**Returns:** Tuple of (cumulative_population_share, cumulative_income_share)

#### Other Inequality Measures

```julia
# Atkinson index
atkinson = atkinson_index(incomes; epsilon=1.0)

# Theil index
theil = theil_index(incomes)

# Percentile ratio (e.g., P90/P10)
ratio = percentile_ratio(incomes, 90, 10)

# Palma ratio (top 10% vs bottom 40%)
palma = palma_ratio(incomes)
```

### Constraints

#### ConstraintSystem

Create and solve economic constraint systems.

```julia
system = ConstraintSystem()

# Add constraint: GDP = C + I + G + NX
add_constraint(system, "GDP_identity", "GDP = C + I + G + NX",
               ["GDP", "C", "I", "G", "NX"],
               [1.0, -1.0, -1.0, -1.0, -1.0],
               0.0)

# Set known values
set_variable(system, "C", 14000.0, fixed=true)
set_variable(system, "I", 3000.0, fixed=true)
set_variable(system, "G", 3500.0, fixed=true)
set_variable(system, "NX", -500.0, fixed=true)

# Solve for GDP
solve_constraints(system)
gdp = get_variable(system, "GDP")  # Returns 20000.0
```

#### gdp_identity_system

Convenience function for GDP identity.

```julia
system = gdp_identity_system(C=14000.0, I=3000.0, G=3500.0, NX=-500.0)
solve_constraints(system)
gdp = get_variable(system, "GDP")
```

---

## Spreadsheet Functions

### Data Functions

#### ECON.FRED

Fetch data from FRED.

```
=ECON.FRED(series_id, start_date, end_date)
```

**Example:**
```
=ECON.FRED("GDPC1", "2020-01-01", "2023-12-31")
```

#### ECON.WB

Fetch data from World Bank.

```
=ECON.WB(indicator_code, country_code, start_date, end_date)
```

**Example:**
```
=ECON.WB("NY.GDP.MKTP.CD", "USA", "2010-01-01", "2020-12-31")
```

#### ECON.SEARCH

Search for data series.

```
=ECON.SEARCH(query, source)
```

**Example:**
```
=ECON.SEARCH("GDP", "FRED")
```

### Formula Functions

#### ECON.ELASTICITY

Calculate elasticity.

```
=ECON.ELASTICITY(quantities_range, prices_range)
```

**Example:**
```
=ECON.ELASTICITY(A2:A10, B2:B10)
```

#### ECON.GROWTH

Calculate growth rates.

```
=ECON.GROWTH(values_range, dates_range, method)
```

**Methods:** "YoY", "QoQ", "MoM", "CAGR"

**Example:**
```
=ECON.GROWTH(A2:A10, B2:B10, "YoY")
```

#### ECON.GINI

Calculate Gini coefficient.

```
=ECON.GINI(incomes_range)
```

**Example:**
```
=ECON.GINI(A2:A100)
```

### Constraint Functions

#### ECON.CONSTRAIN

Define a constraint.

```
=ECON.CONSTRAIN(equation, variables)
```

#### ECON.SOLVE

Solve constraint system.

```
=ECON.SOLVE()
```

---

## TypeScript Adapter API

### ISpreadsheetAdapter Interface

All platform adapters implement this interface.

```typescript
import { createAdapter } from '@/adapters/ISpreadsheetAdapter';

const adapter = createAdapter();
```

### Cell Operations

```typescript
// Get cell value
const value = await adapter.getCellValue("A1");

// Set cell value
await adapter.setCellValue("B2", 123.45);

// Get range
const data = await adapter.getRange("A1", "C10");

// Set range
await adapter.setRange("D1", [[1, 2, 3], [4, 5, 6]]);

// Clear range
await adapter.clearRange("A1", "Z100");
```

### Custom Functions

```typescript
// Register custom function
adapter.registerFunction({
    name: 'ECON.CUSTOM',
    description: 'Custom economic function',
    parameters: [
        { name: 'value', description: 'Input value', type: 'number' }
    ],
    returnType: 'number'
}, async (value) => {
    return value * 2;
});
```

### Events

```typescript
// Selection change
const unsubscribe = adapter.onSelectionChange((address) => {
    console.log(`Selected: ${address}`);
});

// Calculate event
adapter.onCalculate(() => {
    console.log('Calculation complete');
});

// Unsubscribe
unsubscribe();
```

### UI Operations

```typescript
// Show dialog
await adapter.showDialog('<h1>Hello</h1>', {
    title: 'My Dialog',
    width: 400,
    height: 300
});

// Show task pane
await adapter.showTaskPane('data-browser', {
    title: 'Data Browser',
    url: '/taskpane.html'
});

// Show notification
await adapter.showNotification('Data loaded successfully', 'info');
```

### Batch Operations

```typescript
// Execute multiple operations efficiently
await adapter.batch(async () => {
    await adapter.setCellValue("A1", 100);
    await adapter.setCellValue("A2", 200);
    await adapter.setCellValue("A3", 300);
});
```

---

## Error Handling

All APIs use standard error handling:

```julia
try
    data = fetch_series(client, "INVALID_ID", start_date, end_date)
catch e
    if e isa HTTP.Exceptions.StatusError
        println("HTTP error: ", e.status)
    elseif e isa ErrorException
        println("Error: ", e.msg)
    end
end
```

```typescript
try {
    const value = await adapter.getCellValue("A1");
} catch (error) {
    console.error('Failed to get cell value:', error);
}
```

---

## Rate Limits

All data source clients respect rate limits:

| Source | Rate Limit | Notes |
|--------|-----------|-------|
| FRED | 120/min (with key), 5/min (without) | Recommended to use API key |
| World Bank | 60/min | No key required |
| IMF | 60/min | No key required |
| OECD | 60/min | No key required |
| DBnomics | 500/min | High limit, no key required |
| ECB | 60/min | No key required |

---

## Caching

All data is cached with configurable TTL:

```julia
# Custom cache TTL (in seconds)
client = FREDClient(cache_ttl=3600)  # 1 hour

# Clear cache
clear_all(client.cache)

# Get cache statistics
stats = get_stats(client.cache)
```

---

## Performance Tips

1. **Use batch operations** for multiple cell updates
2. **Enable caching** to reduce API calls
3. **Respect rate limits** - automatic with built-in limiters
4. **Use appropriate methods** - log method for elasticity with large datasets
5. **Stream large datasets** - use pagination when available

---

## Support

- GitHub Issues: https://github.com/Hyperpolymath/excel-economic-number-tool-/issues
- Documentation: https://github.com/Hyperpolymath/excel-economic-number-tool-/docs
- Examples: See `examples/` directory
