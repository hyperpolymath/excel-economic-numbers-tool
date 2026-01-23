# Economic Data Integration Standard (EDIS) - v10.0

**Version**: 1.0
**Status**: Draft
**Last Updated**: January 23, 2026

## Abstract

The Economic Data Integration Standard (EDIS) defines a common specification for accessing, transforming, and analyzing economic data across heterogeneous data sources and analytical platforms. EDIS enables interoperability between economic databases, statistical agencies, research institutions, and analytical tools.

## Motivation

### Problem

Economic data exists in fragmented silos:
- Different APIs per data provider
- Incompatible data formats
- Inconsistent metadata
- No standard query language
- Platform lock-in

### Solution

EDIS provides:
- Unified data model
- Standard API specification
- Common query language
- Metadata conventions
- Transformation pipelines

### Benefits

**For Data Providers**:
- Wider adoption
- Reduced support burden
- Interoperable with other providers
- Clear implementation guide

**For Tool Developers**:
- Single integration per standard
- Automatic support for EDIS-compliant providers
- Reduced maintenance

**For End Users**:
- Switch providers seamlessly
- Combine data from multiple sources
- Consistent experience
- No vendor lock-in

## Specification

### 1. Data Model

#### Series

Fundamental unit is a **series**: time-indexed observations of a variable.

```json
{
  "series": {
    "id": "FRED:GDPC1",
    "source": "FRED",
    "name": "Real Gross Domestic Product",
    "description": "Billions of Chained 2017 Dollars, Seasonally Adjusted Annual Rate",
    "frequency": "quarterly",
    "units": "billions_of_dollars",
    "seasonal_adjustment": "seasonally_adjusted",
    "geography": "USA",
    "start_date": "1947-01-01",
    "end_date": "2025-12-31",
    "last_updated": "2026-01-20T10:00:00Z",
    "observations": [
      {"date": "2024-01-01", "value": 20242.5},
      {"date": "2024-04-01", "value": 20533.2},
      {"date": "2024-07-01", "value": 20800.1},
      {"date": "2024-10-01", "value": 21050.8}
    ],
    "metadata": {
      "source_url": "https://fred.stlouisfed.org/series/GDPC1",
      "license": "Public Domain",
      "notes": "..."
    }
  }
}
```

**Required Fields**:
- `id`: Globally unique identifier (format: `SOURCE:ID`)
- `source`: Data provider name
- `name`: Human-readable name
- `frequency`: `daily`, `weekly`, `monthly`, `quarterly`, `annual`
- `observations`: Array of `{date, value}` pairs

**Optional Fields**:
- `description`, `units`, `seasonal_adjustment`, `geography`
- `start_date`, `end_date`, `last_updated`
- `metadata`: Additional provider-specific fields

#### Metadata

**Standard Metadata Fields**:

| Field | Type | Description |
|-------|------|-------------|
| `source_url` | URI | Canonical URL for series |
| `license` | String | Data license (SPDX identifier preferred) |
| `citation` | String | How to cite this data |
| `methodology` | String | Data collection methodology |
| `notes` | String | Additional context |
| `tags` | Array[String] | Categorization tags |
| `related_series` | Array[String] | Related series IDs |

### 2. API Specification

#### REST API

**Base URL**: `https://api.provider.com/edis/v1`

**Endpoints**:

##### List Sources

```
GET /sources
```

Response:
```json
{
  "sources": [
    {
      "id": "FRED",
      "name": "Federal Reserve Economic Data",
      "url": "https://fred.stlouisfed.org",
      "coverage": "USA",
      "series_count": 800000,
      "categories": ["monetary", "fiscal", "labor", "trade"]
    }
  ]
}
```

##### Search Series

```
GET /series/search?q=gdp&source=FRED&limit=10
```

Response:
```json
{
  "results": [
    {
      "id": "FRED:GDPC1",
      "name": "Real Gross Domestic Product",
      "description": "...",
      "frequency": "quarterly",
      "relevance_score": 0.98
    }
  ],
  "total": 450,
  "page": 1,
  "per_page": 10
}
```

##### Get Series

```
GET /series/FRED:GDPC1?start_date=2020-01-01&end_date=2025-12-31
```

Response: Single series object (see Data Model)

##### Get Multiple Series

```
POST /series/batch
Content-Type: application/json

{
  "series_ids": ["FRED:GDPC1", "FRED:UNRATE", "FRED:CPIAUCSL"],
  "start_date": "2020-01-01",
  "end_date": "2025-12-31",
  "align": true
}
```

Response:
```json
{
  "series": [ /* array of series objects */ ],
  "aligned": true,
  "common_frequency": "monthly"
}
```

**Query Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| `start_date` | ISO-8601 | Filter observations >= date |
| `end_date` | ISO-8601 | Filter observations <= date |
| `frequency` | Enum | Resample to frequency |
| `aggregation` | Enum | Aggregation method: `sum`, `avg`, `last`, `first` |
| `units` | Enum | Unit transformation: `levels`, `pct_change`, `log` |
| `seasonal_adj` | Bool | Apply seasonal adjustment |

**HTTP Headers**:

```
Authorization: Bearer {api_key}
X-EDIS-Version: 1.0
Accept: application/json
```

#### GraphQL API (Optional)

```graphql
type Series {
  id: ID!
  source: String!
  name: String!
  description: String
  frequency: Frequency!
  units: String
  observations(
    startDate: Date
    endDate: Date
    frequency: Frequency
  ): [Observation!]!
  metadata: Metadata
}

type Observation {
  date: Date!
  value: Float!
}

type Query {
  series(id: ID!): Series
  searchSeries(
    query: String!
    source: String
    limit: Int = 10
  ): [Series!]!
}
```

### 3. Query Language

**Economic Data Query Language (EDQL)**:

```edql
SELECT GDPC1, UNRATE
FROM FRED
WHERE date >= '2020-01-01'
FREQUENCY monthly
UNITS pct_change
```

**Transformations**:

```edql
SELECT GDPC1
FROM FRED
TRANSFORM growth_rate(period=4)  -- Year-over-year
WHERE date >= '2020-01-01'
```

**Aggregations**:

```edql
SELECT GDP
FROM WorldBank
WHERE country IN ('USA', 'CHN', 'JPN')
AGGREGATE BY year
```

### 4. Data Transformations

**Standard Transformations**:

| Function | Description | Example |
|----------|-------------|---------|
| `growth_rate(period)` | % change over period | YoY growth |
| `moving_average(window)` | Rolling average | 3-month MA |
| `diff(lag)` | First difference | Change |
| `log()` | Natural logarithm | Log levels |
| `normalize(method)` | Standardize | Z-score |
| `seasonal_adjust()` | Remove seasonality | X-13 ARIMA |

**Custom Transformations**:

Providers can register custom transformations:

```json
{
  "transformation": {
    "name": "gdp_per_capita",
    "inputs": ["gdp", "population"],
    "formula": "gdp / population",
    "units": "dollars_per_person"
  }
}
```

### 5. Error Handling

**Standard Error Codes**:

| Code | HTTP | Meaning |
|------|------|---------|
| `SERIES_NOT_FOUND` | 404 | Series ID doesn't exist |
| `INVALID_DATE_RANGE` | 400 | Invalid start/end dates |
| `RATE_LIMIT_EXCEEDED` | 429 | Too many requests |
| `UNAUTHORIZED` | 401 | Invalid/missing API key |
| `FORBIDDEN` | 403 | No access to series |
| `INTERNAL_ERROR` | 500 | Provider error |

**Error Response**:

```json
{
  "error": {
    "code": "SERIES_NOT_FOUND",
    "message": "Series 'FRED:INVALID' not found",
    "details": {
      "series_id": "FRED:INVALID",
      "suggestions": ["FRED:GDPC1", "FRED:GDP"]
    }
  }
}
```

### 6. Authentication

**Supported Methods**:

1. **API Key**: `Authorization: Bearer {key}`
2. **OAuth 2.0**: Standard OAuth flow
3. **JWT**: JSON Web Tokens

**Scopes**:

- `read:series`: Read series data
- `read:metadata`: Read metadata
- `write:series`: Upload data (for contributors)
- `admin`: Administrative access

### 7. Rate Limiting

**Headers**:

```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 995
X-RateLimit-Reset: 1640995200
```

**Limits**:

- Free tier: 1,000 requests/day
- Academic: 10,000 requests/day
- Commercial: 100,000 requests/day
- Enterprise: Custom

## Implementation Guide

### For Data Providers

1. **Map Your Data Model** to EDIS series format
2. **Implement REST API** following spec
3. **Add Metadata** per standard fields
4. **Register** at edis-registry.org
5. **Test** with validation suite
6. **Certify** (optional but recommended)

**Implementation Checklist**:

- [ ] Series model conformance
- [ ] Required API endpoints
- [ ] Error codes
- [ ] Authentication
- [ ] Rate limiting
- [ ] Documentation
- [ ] Client library (optional)

### For Tool Developers

1. **Integrate EDIS Client Library**
2. **Discover Providers** from registry
3. **Query Series** using standard API
4. **Handle Errors** per standard codes
5. **Display Data** with proper attribution

**Sample Code** (Python):

```python
from edis_client import EDISClient

client = EDISClient(api_key="...")

# Search
results = client.search("GDP", source="FRED")

# Get series
series = client.get_series("FRED:GDPC1",
                          start_date="2020-01-01")

# Transform
growth = client.transform(series, "growth_rate", period=4)

# Plot
growth.plot()
```

## Compliance & Certification

### Compliance Levels

**Level 1 - Basic**:
- REST API core endpoints
- Standard data model
- Error handling

**Level 2 - Standard**:
- Level 1 +
- Query language support
- Standard transformations
- GraphQL API (optional)

**Level 3 - Full**:
- Level 2 +
- Real-time updates
- Bulk exports
- Custom transformations
- Advanced metadata

### Certification

**Process**:
1. Implement specification
2. Pass validation test suite
3. Submit for review
4. Receive certification
5. Listed in registry

**Benefits**:
- Official "EDIS Certified" badge
- Listed in provider registry
- Promotion on EDIS website
- Early access to spec updates

**Cost**: Free for open data providers, $500/year for commercial

## Registry

**EDIS Provider Registry**: edis-registry.org

**Registered Providers**:
- FRED (Federal Reserve)
- World Bank
- IMF
- OECD
- ECB
- Eurostat
- Economic Toolkit (reference implementation)

**Adding Your Provider**:
Submit PR at github.com/economictoolkit/edis-registry

## Governance

**Managed By**: Economic Toolkit Foundation

**Technical Committee**:
- 5 members
- 2-year terms
- Approve spec changes
- Review certifications

**Process**:
- RFCs for changes
- Public comment period
- Quarterly releases
- Backward compatibility guarantee

## Versioning

**Current Version**: 1.0

**Compatibility**:
- Major version (1.x): Breaking changes
- Minor version (x.1): New features, backward compatible
- Patch version (x.x.1): Bug fixes

**Deprecation Policy**:
- 6 months notice
- Migration guide provided
- Support for 2 versions

## License

**Specification**: CC0 1.0 Universal (Public Domain)

Anyone can implement, no royalties, no restrictions.

## References

1. SDMX (Statistical Data and Metadata Exchange)
2. JSON-LD for Linked Data
3. OpenAPI 3.0 Specification
4. GraphQL Specification
5. ISO 8601 Date/Time Format

## Contact

- **Specification Questions**: edis-spec@economictoolkit.org
- **Implementation Help**: edis-support@economictoolkit.org
- **Certification**: edis-certification@economictoolkit.org
- **GitHub**: github.com/economictoolkit/edis-spec

---

**Authors**: Economic Toolkit Foundation & Community
**License**: CC0 1.0 Universal
**Last Updated**: January 23, 2026
