# Economic Data Sources Documentation

This document provides comprehensive information about the major economic data sources that can be integrated with the Excel Economic Number Tool.

## Table of Contents

1. [FRED (Federal Reserve Economic Data)](#1-fred-federal-reserve-economic-data)
2. [World Bank](#2-world-bank)
3. [IMF (International Monetary Fund)](#3-imf-international-monetary-fund)
4. [OECD](#4-oecd)
5. [DBnomics](#5-dbnomics)
6. [ECB (European Central Bank)](#6-ecb-european-central-bank)
7. [BEA (Bureau of Economic Analysis)](#7-bea-bureau-of-economic-analysis)
8. [Census Bureau](#8-census-bureau)
9. [Eurostat](#9-eurostat)
10. [BIS (Bank for International Settlements)](#10-bis-bank-for-international-settlements)

---

## 1. FRED (Federal Reserve Economic Data)

### Overview and Coverage
FRED is a comprehensive database maintained by the Federal Reserve Bank of St. Louis, containing over 800,000 economic time series from 100+ sources. Coverage includes U.S. and international data on:
- GDP and national accounts
- Employment and unemployment
- Interest rates and monetary aggregates
- Prices and inflation
- Exchange rates
- Banking and finance
- International trade

### API Endpoints
**Base URL**: `https://api.stlouisfed.org/fred/`

Key endpoints:
- Series observations: `series/observations`
- Series info: `series`
- Series search: `series/search`
- Categories: `category`
- Releases: `releases`

### Rate Limits
- **Limit**: 120 requests per 60 seconds
- **Daily limit**: No official daily limit, but sustained high-volume usage should be coordinated
- **Best practice**: Implement request throttling and caching

### Authentication Requirements
- **API Key Required**: Yes (free)
- **Registration**: https://fred.stlouisfed.org/docs/api/api_key.html
- **Format**: API key passed as URL parameter `api_key`
- **Cost**: Free for all users

### Example Series IDs
- `GDP` - Gross Domestic Product
- `UNRATE` - Unemployment Rate
- `CPIAUCSL` - Consumer Price Index for All Urban Consumers
- `DFF` - Federal Funds Effective Rate
- `DEXUSEU` - U.S./Euro Foreign Exchange Rate
- `T10Y2Y` - 10-Year Treasury Constant Maturity Minus 2-Year
- `PAYEMS` - All Employees: Total Nonfarm
- `HOUST` - Housing Starts

### Usage Examples

```python
import requests

api_key = "your_fred_api_key"
series_id = "GDP"

# Get series observations
url = f"https://api.stlouisfed.org/fred/series/observations"
params = {
    "series_id": series_id,
    "api_key": api_key,
    "file_type": "json"
}

response = requests.get(url, params=params)
data = response.json()

# Access observations
for obs in data['observations']:
    print(f"Date: {obs['date']}, Value: {obs['value']}")
```

```javascript
// JavaScript/Node.js example
const axios = require('axios');

const API_KEY = 'your_fred_api_key';
const SERIES_ID = 'UNRATE';

async function getFredData() {
    const response = await axios.get('https://api.stlouisfed.org/fred/series/observations', {
        params: {
            series_id: SERIES_ID,
            api_key: API_KEY,
            file_type: 'json'
        }
    });
    return response.data.observations;
}
```

### Data Format
- **Output formats**: JSON, XML
- **Date format**: YYYY-MM-DD
- **Missing values**: Represented as "."
- **Structure**: Array of observations with date and value pairs

### Update Frequency
- Varies by series (daily, weekly, monthly, quarterly, annual)
- Series metadata includes update frequency information
- Most popular series updated within 1-2 business days of official release

---

## 2. World Bank

### Overview and Coverage
The World Bank provides access to over 16,000 development indicators covering 200+ countries and regions. Data spans from 1960 to present, including:
- Economic indicators (GDP, GNI, trade)
- Social development (education, health, poverty)
- Environmental data
- Infrastructure and development
- Financial sector indicators
- Governance metrics

### API Endpoints
**Base URL**: `https://api.worldbank.org/v2/`

Key endpoints:
- Indicators: `country/{country_code}/indicator/{indicator_code}`
- Countries: `country`
- Indicators list: `indicator`
- Topics: `topic`
- Sources: `source`

### Rate Limits
- **Limit**: No official hard limit
- **Recommended**: Maximum 5 requests per second
- **Pagination**: Default 50 records per page, max 32,500 per request
- **Best practice**: Use per_page parameter to reduce number of requests

### Authentication Requirements
- **API Key Required**: No
- **Registration**: Not required
- **Open access**: All data freely available
- **Attribution**: Required when using data

### Example Series IDs (Indicator Codes)
- `NY.GDP.MKTP.CD` - GDP (current US$)
- `NY.GDP.PCAP.CD` - GDP per capita (current US$)
- `FP.CPI.TOTL.ZG` - Inflation, consumer prices (annual %)
- `SL.UEM.TOTL.ZS` - Unemployment, total (% of total labor force)
- `NE.EXP.GNFS.ZS` - Exports of goods and services (% of GDP)
- `SP.POP.TOTL` - Population, total
- `SE.PRM.ENRR` - School enrollment, primary (% gross)

### Usage Examples

```python
import requests

country_code = "USA"
indicator_code = "NY.GDP.MKTP.CD"

# Get GDP data for USA
url = f"https://api.worldbank.org/v2/country/{country_code}/indicator/{indicator_code}"
params = {
    "format": "json",
    "date": "2010:2023",
    "per_page": 100
}

response = requests.get(url, params=params)
data = response.json()

# Data is in second element of response array
if len(data) > 1:
    for entry in data[1]:
        print(f"Year: {entry['date']}, GDP: {entry['value']}")
```

```javascript
// JavaScript example
async function getWorldBankData(countryCode, indicatorCode) {
    const url = `https://api.worldbank.org/v2/country/${countryCode}/indicator/${indicatorCode}`;
    const response = await fetch(`${url}?format=json&date=2010:2023&per_page=100`);
    const data = await response.json();
    return data[1]; // Actual data is in second array element
}
```

### Data Format
- **Output formats**: JSON, XML
- **Date format**: Year (YYYY) for annual data
- **Missing values**: `null`
- **Structure**: Array with metadata object followed by data array
- **Pagination**: Includes page, pages, per_page, and total in response

### Update Frequency
- **Annual data**: Most indicators updated annually
- **Quarterly data**: Limited availability
- **Update schedule**: Typically 6-12 months after period end
- **Revisions**: Historical data may be revised

---

## 3. IMF (International Monetary Fund)

### Overview and Coverage
The IMF provides comprehensive international economic and financial data through multiple databases:
- International Financial Statistics (IFS)
- Balance of Payments (BOP)
- Direction of Trade Statistics (DOTS)
- Government Finance Statistics (GFS)
- World Economic Outlook (WEO)
- Financial Soundness Indicators (FSI)

Coverage includes 190+ member countries with historical data dating back to 1948 for some series.

### API Endpoints
**Base URL**: `http://dataservices.imf.org/REST/SDMX_JSON.svc/`

Key endpoints:
- Dataflow: `Dataflow/{database}`
- Data structure: `DataStructure/{database}`
- Compact data: `CompactData/{database}/{frequency}.{country}.{indicator}`
- Generic metadata: `GenericMetadata/{database}`

Common database codes: `IFS`, `BOP`, `DOTS`, `FSI`, `WEO`

### Rate Limits
- **Limit**: 10 requests per second
- **Daily limit**: Not officially specified
- **Response size**: Maximum 1 million records per request
- **Best practice**: Implement retry logic with exponential backoff

### Authentication Requirements
- **API Key Required**: No
- **Registration**: Not required for public data
- **SDMX format**: Standard format, may require SDMX library
- **Attribution**: Required

### Example Series IDs
IFS (International Financial Statistics):
- `PCPI_IX` - Consumer Price Index
- `FPOLM_PA` - Interest Rates, Policy Rate
- `ENDA_XDC_USD_RATE` - Exchange Rates, USD
- `NGDP_XDC` - GDP, National Currency
- `TX_RPT_TotMerch_USD` - Exports, Merchandise, USD

### Usage Examples

```python
import requests

database = "IFS"
frequency = "M"  # M=Monthly, Q=Quarterly, A=Annual
country = "US"
indicator = "PCPI_IX"

# Get CPI data for US
dimension_string = f"{frequency}.{country}.{indicator}"
url = f"http://dataservices.imf.org/REST/SDMX_JSON.svc/CompactData/{database}/{dimension_string}"

params = {
    "startPeriod": "2020-01",
    "endPeriod": "2023-12"
}

response = requests.get(url, params=params)
data = response.json()

# Parse SDMX structure
series = data['CompactData']['DataSet']['Series']
if 'Obs' in series:
    for obs in series['Obs']:
        print(f"Period: {obs['@TIME_PERIOD']}, Value: {obs['@OBS_VALUE']}")
```

```python
# Using IMF Data API wrapper (recommended)
# pip install imfpy

from imfpy import imf

# Fetch IFS data
df = imf.get_data(
    database='IFS',
    country='US',
    indicator='PCPI_IX',
    start_year=2020,
    end_year=2023
)
print(df)
```

### Data Format
- **Output format**: SDMX-JSON (Statistical Data and Metadata eXchange)
- **Date format**: YYYY-MM for monthly, YYYY-QQ for quarterly, YYYY for annual
- **Missing values**: Omitted from response
- **Structure**: Nested JSON with CompactData > DataSet > Series > Obs
- **Metadata**: Included in response with descriptions and units

### Update Frequency
- **IFS**: Monthly (updated mid-month)
- **BOP**: Quarterly (2-3 months after quarter end)
- **WEO**: Semi-annually (April and October)
- **GFS**: Annually
- **Real-time updates**: Some indicators updated daily

---

## 4. OECD

### Overview and Coverage
The Organization for Economic Co-operation and Development (OECD) provides statistical data for 38 member countries and over 100 partner economies. Coverage includes:
- National accounts and GDP
- Labor market statistics
- Prices and purchasing power
- Trade and balance of payments
- Education and skills
- Health statistics
- Environmental indicators
- Government finance

### API Endpoints
**Base URL**: `https://stats.oecd.org/SDMX-JSON/data/`

Key endpoints:
- Data: `{dataset}/{filter}/{agency}`
- Dataflow: `https://stats.oecd.org/restsdmx/sdmx.ashx/GetDataStructure/{dataset}`
- All datasets: `https://stats.oecd.org/restsdmx/sdmx.ashx/GetDataStructure/ALL`

Common datasets: `QNA` (Quarterly National Accounts), `MEI` (Main Economic Indicators), `SNA_TABLE1` (Annual National Accounts)

### Rate Limits
- **Limit**: No official published rate limit
- **Best practice**: Limit to 100 requests per minute
- **Response size**: Large queries may timeout
- **Recommendation**: Use filters to narrow queries

### Authentication Requirements
- **API Key Required**: No
- **Registration**: Not required
- **Open access**: All statistics freely available
- **Commercial use**: Permitted with attribution

### Example Series IDs
From MEI (Main Economic Indicators):
- Dataset: `MEI`
- Countries: `USA`, `GBR`, `JPN`, `DEU`, etc.
- Subjects: `PRMNTO01` (CPI), `LRHUTTTT` (Unemployment), `XTEXVA01` (Exports)
- Frequency: `M` (Monthly), `Q` (Quarterly), `A` (Annual)

### Usage Examples

```python
import requests

dataset = "MEI"
# Format: COUNTRY.SUBJECT.MEASURE.FREQUENCY
location = "USA"
subject = "PRMNTO01"  # CPI All items
measure = "IXOB"      # Index
frequency = "M"       # Monthly

filter_expression = f"{location}.{subject}.{measure}.{frequency}"
url = f"https://stats.oecd.org/SDMX-JSON/data/{dataset}/{filter_expression}/all"

params = {
    "startTime": "2020-01",
    "endTime": "2023-12"
}

response = requests.get(url, params=params)
data = response.json()

# Parse SDMX structure
observations = data['dataSets'][0]['observations']
for key, value in observations.items():
    print(f"Observation: {value[0]}")
```

```python
# Using pandasdmx library (recommended)
# pip install pandasdmx

import pandasdmx as sdmx

oecd = sdmx.Request('OECD')

# Get data
data_response = oecd.data(
    resource_id='MEI',
    key={'LOCATION': 'USA', 'SUBJECT': 'PRMNTO01'},
    params={'startTime': '2020', 'endTime': '2023'}
)

# Convert to pandas DataFrame
df = sdmx.to_pandas(data_response)
print(df)
```

### Data Format
- **Output format**: SDMX-JSON
- **Date format**: YYYY-MM, YYYY-QQ, or YYYY depending on frequency
- **Missing values**: Not included in observations object
- **Structure**: Complex nested structure with dataSets and observations
- **Metadata**: Series keys map to dimension values

### Update Frequency
- **National Accounts**: Quarterly (2-3 months after quarter end)
- **MEI**: Monthly (typically within 30 days)
- **Annual data**: Varies by indicator (6-12 months after year end)
- **Revisions**: Data subject to revision; historical data may change

---

## 5. DBnomics

### Overview and Coverage
DBnomics is an aggregator that provides unified access to economic databases from over 60 providers, including:
- National statistical institutes
- Central banks
- International organizations (IMF, World Bank, OECD, Eurostat, BIS)
- Research institutions

Total coverage: 500+ million time series from diverse sources through a single API.

### API Endpoints
**Base URL**: `https://api.db.nomics.world/v22/`

Key endpoints:
- Series data: `series/{provider_code}/{dataset_code}/{series_code}`
- Multiple series: `series`
- Search series: `series?q={query}`
- Datasets list: `datasets/{provider_code}`
- Providers list: `providers`

### Rate Limits
- **Limit**: 50 requests per 10 seconds per IP
- **Burst**: Short bursts allowed
- **Large downloads**: Use bulk download options
- **Best practice**: Cache data locally when possible

### Authentication Requirements
- **API Key Required**: No for basic usage
- **Registration**: Optional (provides higher rate limits)
- **Premium access**: Available for high-volume users
- **Open source**: Free for all users

### Example Series IDs
Format: `{provider}/{dataset}/{series}`

Examples:
- `FRED/GDP` - US GDP from FRED
- `ECB/ILM/M.U2.Y.L0.L.X.ALL` - ECB interest rate data
- `Eurostat/namq_10_gdp/Q.NSA.CLV10_MNAC.B1GQ.DE` - German GDP
- `IMF/IFS/M.US.PCPI_IX` - US CPI from IMF
- `WB/WDI/NY.GDP.MKTP.CD.USA` - US GDP from World Bank

### Usage Examples

```python
import requests

provider = "FRED"
dataset = "series"
series_code = "GDP"

# Get series data
url = f"https://api.db.nomics.world/v22/series/{provider}/{dataset}/{series_code}"

params = {
    "observations": 1,  # Include observations
    "limit": 1000
}

response = requests.get(url, params=params)
data = response.json()

# Access observations
for obs in data['series']['observations']:
    print(f"Period: {obs['period']}, Value: {obs['value']}")
```

```python
# Using DBnomics Python package (recommended)
# pip install dbnomics

from dbnomics import fetch_series

# Fetch single series
df = fetch_series('FRED/series/GDP')
print(df)

# Fetch multiple series
series_list = ['FRED/series/GDP', 'FRED/series/UNRATE']
df_multi = fetch_series(series_list)
print(df_multi)
```

```r
# R example using rdbnomics package
library(rdbnomics)

# Fetch series
df <- rdb(ids = c('FRED/series/GDP', 'FRED/series/UNRATE'))
print(df)
```

### Data Format
- **Output format**: JSON
- **Date format**: ISO 8601 (YYYY-MM-DD)
- **Missing values**: `null` or omitted
- **Structure**: Standardized across all providers
- **Metadata**: Included with series information

### Update Frequency
- **Synchronization**: Updates from source providers daily
- **Lag**: Typically 24 hours from original source
- **Provider dependent**: Inherits update frequency from source
- **Status**: API provides last update timestamp

---

## 6. ECB (European Central Bank)

### Overview and Coverage
The ECB Statistical Data Warehouse provides comprehensive European monetary and financial statistics:
- Euro area monetary aggregates
- Interest rates and yields
- Exchange rates
- Balance of payments
- Financial markets data
- Banking statistics
- Government finance statistics

Coverage includes all EU member states and Euro area aggregate data.

### API Endpoints
**Base URL**: `https://sdw-wsrest.ecb.europa.eu/service/`

Key endpoints:
- Data: `data/{flowRef}/{key}`
- Dataflow: `dataflow`
- Data structure: `datastructure/{agency}/{id}/{version}`
- Metadata: `metadata/{structureType}/{agencyId}/{resourceId}`

### Rate Limits
- **Limit**: 50 requests per 10 seconds per IP
- **Response size**: Maximum 1 million observations
- **Concurrent requests**: Limited to 5
- **Best practice**: Implement request queuing

### Authentication Requirements
- **API Key Required**: No
- **Registration**: Not required
- **Open access**: All data freely available
- **Terms**: Non-commercial and commercial use permitted

### Example Series IDs
ECB series follow SDMX format: `Dataset.Frequency.Dimensions...`

Examples:
- `EXR.D.USD.EUR.SP00.A` - Daily USD/EUR exchange rate
- `FM.M.U2.EUR.4F.KR.MRR_FR.LEV` - ECB main refinancing rate
- `ILM.M.U2.C.L020000.U2.EUR` - Loans to households
- `ICP.M.U2.N.000000.4.ANR` - HICP All items annual rate
- `BP6.M.N.I8.W1.S1.S1.T.N.FA.F.F7.T.EUR._T.T.N` - Balance of payments

### Usage Examples

```python
import requests

dataset = "EXR"  # Exchange Rates
frequency = "D"  # Daily
currency1 = "USD"
currency2 = "EUR"
series_variant = "SP00"
series_type = "A"

key = f"{frequency}.{currency1}.{currency2}.{series_variant}.{series_type}"
url = f"https://sdw-wsrest.ecb.europa.eu/service/data/{dataset}/{key}"

params = {
    "startPeriod": "2023-01-01",
    "endPeriod": "2023-12-31",
    "format": "jsondata"
}

response = requests.get(url, params=params)
data = response.json()

# Parse ECB SDMX structure
dataset = data['dataSets'][0]
observations = dataset['observations']
for key, values in observations.items():
    print(f"Value: {values[0]}")
```

```python
# Using pandasdmx for ECB data
import pandasdmx as sdmx

ecb = sdmx.Request('ECB')

# Get exchange rate data
data_response = ecb.data(
    resource_id='EXR',
    key={'CURRENCY': 'USD', 'CURRENCY_DENOM': 'EUR', 'FREQ': 'D'},
    params={'startPeriod': '2023-01', 'endPeriod': '2023-12'}
)

# Convert to pandas
df = sdmx.to_pandas(data_response)
print(df)
```

### Data Format
- **Output formats**: SDMX-ML (XML), SDMX-JSON, CSV, TSV
- **Date format**: YYYY-MM-DD for daily, YYYY-MM for monthly
- **Missing values**: Omitted from observations
- **Structure**: SDMX 2.1 compliant
- **Compression**: gzip supported

### Update Frequency
- **Exchange rates**: Daily (updated at 16:00 CET)
- **Monetary aggregates**: Monthly (around 10th working day)
- **Interest rates**: Daily/Monthly depending on series
- **Balance of payments**: Quarterly (70 days after quarter end)
- **Real-time**: Some series updated in real-time

---

## 7. BEA (Bureau of Economic Analysis)

### Overview and Coverage
The U.S. Bureau of Economic Analysis provides comprehensive U.S. economic statistics:
- National Income and Product Accounts (NIPA)
- GDP by industry and state
- Personal income and outlays
- International transactions (balance of payments, trade)
- Regional economic accounts
- Fixed assets and capital flows
- Input-output accounts

### API Endpoints
**Base URL**: `https://apps.bea.gov/api/data/`

Key parameters:
- Method: `GetData`, `GetDataSetList`, `GetParameterList`, `GetParameterValues`
- Dataset: `NIPA`, `NIUnderlyingDetail`, `FixedAssets`, `ITA`, `IIP`, `GDPbyIndustry`, `Regional`

### Rate Limits
- **Limit**: 1000 API calls per day
- **Request frequency**: No specific rate limit per second
- **Reset**: Daily at midnight EST
- **Monitoring**: Track via response headers

### Authentication Requirements
- **API Key Required**: Yes (free)
- **Registration**: https://apps.bea.gov/API/signup/
- **Format**: API key passed as URL parameter `UserID`
- **Cost**: Free for all users

### Example Series IDs
NIPA Tables:
- Table 1.1.5 - Gross Domestic Product
- Table 2.3.5 - Personal Consumption Expenditures by Major Type of Product
- Table 3.1 - Government Current Receipts and Expenditures
- Table 7.1 - Selected Per Capita Product and Income

Parameters:
- `TableName`: e.g., "T10101"
- `Frequency`: "Q" (Quarterly), "A" (Annual), "M" (Monthly)
- `Year`: "X" for all years or specific year

### Usage Examples

```python
import requests

api_key = "your_bea_api_key"
method = "GetData"
dataset = "NIPA"

# Get GDP data (Table 1.1.5)
params = {
    "UserID": api_key,
    "method": method,
    "datasetname": dataset,
    "TableName": "T10105",
    "Frequency": "Q",
    "Year": "X",
    "ResultFormat": "JSON"
}

url = "https://apps.bea.gov/api/data/"
response = requests.get(url, params=params)
data = response.json()

# Parse BEA response
results = data['BEAAPI']['Results']['Data']
for item in results:
    print(f"Period: {item.get('TimePeriod')}, Value: {item.get('DataValue')}")
```

```python
# Get available datasets
def get_datasets(api_key):
    params = {
        "UserID": api_key,
        "method": "GetDataSetList",
        "ResultFormat": "JSON"
    }
    response = requests.get("https://apps.bea.gov/api/data/", params=params)
    return response.json()

# Get parameters for a dataset
def get_parameters(api_key, dataset):
    params = {
        "UserID": api_key,
        "method": "GetParameterList",
        "datasetname": dataset,
        "ResultFormat": "JSON"
    }
    response = requests.get("https://apps.bea.gov/api/data/", params=params)
    return response.json()
```

### Data Format
- **Output formats**: JSON, XML
- **Date format**: YYYY for annual, YYYYQQ for quarterly, YYYY-MM for monthly
- **Missing values**: Empty string or "..."
- **Structure**: BEAAPI > Results > Data array
- **Notes**: Additional metadata in NoteRef fields

### Update Frequency
- **GDP (advance)**: Released ~1 month after quarter end
- **GDP (second estimate)**: ~2 months after quarter end
- **GDP (third estimate)**: ~3 months after quarter end
- **Personal income**: Monthly (~1 month lag)
- **International transactions**: Quarterly (~70 days after quarter end)
- **Annual revisions**: Typically in July-September

---

## 8. Census Bureau

### Overview and Coverage
The U.S. Census Bureau provides economic and demographic data through multiple APIs:
- Economic indicators (retail sales, construction, manufacturing)
- International trade data
- Population and demographic statistics
- Business and industry statistics
- Housing data
- Income and poverty statistics

### API Endpoints
**Base URL**: `https://api.census.gov/data/`

Key datasets:
- Economic indicators: `timeseries/eits/{indicator}`
- International trade: `timeseries/intltrade/{imports|exports}/{hs|sitc|naics}`
- ACS (American Community Survey): `{year}/acs/acs5`
- Population estimates: `{year}/pep/population`

### Rate Limits
- **Limit**: 500 requests per IP per day (unauthenticated)
- **With key**: 5000 requests per day
- **Best practice**: Implement caching and pagination
- **Concurrent**: Limit to 5 concurrent requests

### Authentication Requirements
- **API Key Required**: Recommended but not required for basic usage
- **Registration**: https://api.census.gov/data/key_signup.html
- **Format**: API key passed as URL parameter `key`
- **Cost**: Free

### Example Series IDs
Economic Indicators Time Series (EITS):
- `RETAIL` - Retail Sales
- `MANU` - Manufacturers' Shipments, Inventories, and Orders
- `RESSALES` - New Residential Sales
- `RESCONSTRUCTION` - New Residential Construction
- `HOUSING` - Housing Vacancies and Homeownership

### Usage Examples

```python
import requests

api_key = "your_census_api_key"

# Get retail sales data
dataset = "timeseries/eits/retail"
url = f"https://api.census.gov/data/{dataset}"

params = {
    "get": "cell_value,data_type_code,time_slot_id,error_data,category_code,seasonally_adj",
    "time": "2023",
    "key": api_key
}

response = requests.get(url, params=params)
data = response.json()

# First row is headers
headers = data[0]
for row in data[1:]:
    record = dict(zip(headers, row))
    print(record)
```

```python
# Get international trade data (exports)
def get_trade_data(api_key, year, month):
    dataset = "timeseries/intltrade/exports/hs"
    url = f"https://api.census.gov/data/{dataset}"

    params = {
        "get": "CTY_CODE,CTY_NAME,I_COMMODITY,I_COMMODITY_LDESC,ALL_VAL_MO,ALL_VAL_YR",
        "time": f"{year}-{month:02d}",
        "key": api_key
    }

    response = requests.get(url, params=params)
    return response.json()

# Usage
trade_data = get_trade_data("your_key", 2023, 6)
```

### Data Format
- **Output format**: JSON (array of arrays)
- **Date format**: YYYY-MM for monthly, YYYY for annual
- **Missing values**: null, "N", or "X" depending on reason
- **Structure**: First row contains column headers
- **Flags**: Error codes and seasonal adjustment indicators included

### Update Frequency
- **Retail sales**: Monthly (~2 weeks after month end)
- **Manufacturing**: Monthly (~4 weeks after month end)
- **Construction**: Monthly (~1 month after month end)
- **Trade data**: Monthly (~6 weeks after month end)
- **Revisions**: Data subject to revision for 2-3 months

---

## 9. Eurostat

### Overview and Coverage
Eurostat is the statistical office of the European Union, providing harmonized statistics for:
- European economy (GDP, national accounts)
- Population and social conditions
- Industry, trade, and services
- Agriculture and fisheries
- International trade
- Transport and energy
- Environment and climate change

Coverage includes all EU member states, candidate countries, and EFTA members.

### API Endpoints
**Base URL**: `https://ec.europa.eu/eurostat/api/dissemination/`

Key endpoints:
- Statistics: `statistics/1.0/data/{dataset}`
- Metadata: `catalogue/toc/txt`
- SDMX: `sdmx/2.1/data/{dataset}/{filter}`

**Bulk download**: `https://ec.europa.eu/eurostat/estat-navtree-portlet-prod/BulkDownloadListing`

### Rate Limits
- **Limit**: No official hard limit
- **Recommended**: Maximum 10 requests per second
- **Response size**: Large queries may be slow or timeout
- **Best practice**: Use filters and pagination

### Authentication Requirements
- **API Key Required**: No
- **Registration**: Not required
- **Open access**: All data freely available
- **License**: CC BY 4.0

### Example Series IDs (Dataset Codes)
- `nama_10_gdp` - GDP and main components
- `prc_hicp_midx` - HICP - monthly index
- `une_rt_m` - Unemployment by sex and age - monthly data
- `ext_lt_maineu` - EU trade since 1988 by HS2-4
- `gov_10a_main` - Government revenue, expenditure and main aggregates
- `demo_pjan` - Population on 1 January by age and sex
- `nrg_bal_c` - Energy balance sheets

### Usage Examples

```python
import requests

dataset = "nama_10_gdp"

# Get GDP data
url = f"https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/{dataset}"

params = {
    "format": "JSON",
    "lang": "en",
    "geo": "DE",  # Germany
    "na_item": "B1GQ",  # GDP
    "unit": "CP_MEUR",  # Current prices, million euros
    "time": "2020,2021,2022,2023"
}

response = requests.get(url, params=params)
data = response.json()

# Parse Eurostat JSON format
values = data['value']
dimensions = data['dimension']
print(f"Dataset: {data['label']}")
for idx, val in values.items():
    print(f"Index {idx}: {val}")
```

```python
# Using eurostat Python package (recommended)
# pip install eurostat

import eurostat

# Download dataset
df = eurostat.get_data_df('nama_10_gdp')

# Filter data
df_filtered = df[
    (df['geo'] == 'DE') &
    (df['na_item'] == 'B1GQ') &
    (df['unit'] == 'CP_MEUR')
]
print(df_filtered)

# Get table of contents
toc = eurostat.get_toc_df()
print(toc[toc['title'].str.contains('GDP')])
```

```r
# R example using eurostat package
library(eurostat)

# Search for datasets
search_results <- search_eurostat("GDP")

# Get data
data <- get_eurostat("nama_10_gdp", time_format="num")

# Filter
library(dplyr)
data_filtered <- data %>%
  filter(geo == "DE", na_item == "B1GQ", unit == "CP_MEUR")
```

### Data Format
- **Output formats**: JSON, CSV, TSV
- **SDMX**: Also available in SDMX-ML and SDMX-JSON
- **Date format**: YYYY for annual, YYYY-MM for monthly, YYYY-QQ for quarterly
- **Missing values**: ":" in CSV, null in JSON
- **Flags**: p (provisional), e (estimated), b (break in time series)

### Update Frequency
- **GDP**: Quarterly (T+45 days and T+70 days)
- **HICP**: Monthly (~17 days after month end)
- **Unemployment**: Monthly (~1 month after reference month)
- **Trade data**: Monthly (~70 days after month end)
- **Revisions**: Ongoing; flash estimates followed by full estimates

---

## 10. BIS (Bank for International Settlements)

### Overview and Coverage
The BIS provides international banking and financial statistics:
- Effective exchange rate indices
- Credit to the private non-financial sector
- Debt service ratios
- Property prices (residential and commercial)
- Global liquidity indicators
- OTC derivatives statistics
- Locational and consolidated banking statistics
- Central bank policy rates

Coverage includes over 60 countries and territories.

### API Endpoints
**Base URL**: `https://www.bis.org/api/v2/`

Key endpoints:
- Datasets list: `datasets`
- Dataset metadata: `datasets/{id}`
- Data: `datasets/{id}/data`
- Full data URL: `https://data.bis.org/api/v2/datasets/{id}/data/`

### Rate Limits
- **Limit**: Not officially published
- **Recommended**: Maximum 60 requests per minute
- **Response size**: Can be large; use pagination
- **Best practice**: Cache data and use conditional requests

### Authentication Requirements
- **API Key Required**: No
- **Registration**: Not required
- **Open access**: All data freely available
- **Attribution**: Required when using data

### Example Series IDs (Dataset Codes)
- `WS_EER` - Effective exchange rate indices
- `WS_LONG_CPI` - Consumer prices - Long series
- `WS_CBPOL` - Central bank policy rates
- `WS_TC` - Total credit to the private non-financial sector
- `WS_DSR` - Debt service ratios for the private non-financial sector
- `WS_LBS_D_PUB` - Locational banking statistics
- `WS_OTC_DERIV2` - OTC derivatives outstanding

### Usage Examples

```python
import requests

dataset = "WS_CBPOL"  # Central bank policy rates

# Get dataset metadata
url = f"https://data.bis.org/api/v2/datasets/{dataset}"
response = requests.get(url)
metadata = response.json()

# Get data
data_url = f"https://data.bis.org/api/v2/datasets/{dataset}/data/"
params = {
    "format": "json",
    "detail": "dataonly"
}

response = requests.get(data_url, params=params)
data = response.json()

# Parse BIS data structure
if 'dataSets' in data:
    observations = data['dataSets'][0]['observations']
    dimensions = data['structure']['dimensions']['observation']

    for key, values in observations.items():
        print(f"Key: {key}, Value: {values[0]}")
```

```python
# Get specific country policy rate
def get_policy_rate(country_code, start_date=None, end_date=None):
    """
    Get central bank policy rate for a country
    country_code: e.g., 'US', 'GB', 'JP'
    """
    dataset = "WS_CBPOL"
    url = f"https://data.bis.org/api/v2/datasets/{dataset}/data/"

    params = {
        "format": "json",
        "detail": "full"
    }

    if start_date:
        params['startPeriod'] = start_date
    if end_date:
        params['endPeriod'] = end_date

    response = requests.get(url, params=params)
    return response.json()

# Usage
policy_rates = get_policy_rate('US', '2020-01', '2023-12')
```

```python
# Using pandas to work with BIS data
import pandas as pd
import requests

dataset = "WS_TC"  # Total credit
url = f"https://data.bis.org/api/v2/datasets/{dataset}/data/"

params = {
    "format": "csv",
    "locale": "en"
}

response = requests.get(url, params=params)

# Load into pandas
from io import StringIO
df = pd.read_csv(StringIO(response.text))
print(df.head())

# Filter for specific country
df_us = df[df['Reference area'] == 'United States']
```

### Data Format
- **Output formats**: JSON (SDMX-JSON), CSV, XLSX
- **Date format**: YYYY-QQ for quarterly, YYYY for annual, YYYY-MM for monthly
- **Missing values**: null or empty in CSV
- **Structure**: SDMX 2.1 compliant
- **Metadata**: Comprehensive metadata included

### Update Frequency
- **Exchange rates**: Daily (EER indices quarterly)
- **Credit statistics**: Quarterly (~3-4 months after quarter end)
- **Property prices**: Quarterly (~3-4 months after quarter end)
- **Policy rates**: Updated as announced by central banks
- **OTC derivatives**: Semi-annual
- **Banking statistics**: Quarterly

---

## General Best Practices

### Data Integration Tips
1. **Caching**: Cache data locally to minimize API calls
2. **Error handling**: Implement robust error handling for network issues and API errors
3. **Rate limiting**: Respect rate limits; implement exponential backoff
4. **Metadata**: Store series metadata to understand units and frequency
5. **Validation**: Validate data ranges and check for anomalies
6. **Versioning**: Some APIs version data; track which version you're using

### Data Quality Considerations
1. **Revisions**: Economic data is often revised; track vintages when necessary
2. **Seasonal adjustment**: Be aware whether series is seasonally adjusted
3. **Units**: Pay attention to units (levels vs. rates, millions vs. billions)
4. **Missing values**: Handle missing values appropriately for your use case
5. **Break in series**: Watch for methodological changes in long time series

### Performance Optimization
1. **Parallel requests**: Make independent requests in parallel when possible
2. **Compression**: Use gzip compression when supported
3. **Pagination**: Use pagination for large datasets
4. **Filters**: Apply filters server-side rather than downloading everything
5. **Incremental updates**: Only fetch new data rather than full historical series

### Attribution Requirements
Most data sources require attribution when using their data. Example formats:

- **FRED**: "Source: Federal Reserve Economic Data (FRED), Federal Reserve Bank of St. Louis"
- **World Bank**: "Source: World Bank Development Indicators"
- **IMF**: "Source: International Monetary Fund"
- **OECD**: "Source: OECD Statistics"
- **ECB**: "Source: European Central Bank Statistical Data Warehouse"

---

## Additional Resources

### API Client Libraries
- **Python**: `fredapi`, `pandas-datareader`, `wbdata`, `imfpy`, `pandasdmx`, `dbnomics`, `eurostat`
- **R**: `fredr`, `WDI`, `OECD`, `eurostat`, `rdbnomics`, `BIS`
- **JavaScript**: Various npm packages for specific APIs
- **Julia**: `DataFrames.jl`, `FredData.jl`

### Documentation Links
- FRED: https://fred.stlouisfed.org/docs/api/
- World Bank: https://datahelpdesk.worldbank.org/knowledgebase/topics/125589
- IMF: https://datahelp.imf.org/knowledgebase/topics/180312-api
- OECD: https://data.oecd.org/api/
- DBnomics: https://api.db.nomics.world/v22/apidocs
- ECB: https://data.ecb.europa.eu/help/api/overview
- BEA: https://apps.bea.gov/api/
- Census: https://www.census.gov/data/developers/guidance.html
- Eurostat: https://ec.europa.eu/eurostat/web/main/data/web-services
- BIS: https://www.bis.org/statistics/api_documentation.htm

### Support and Community
- Most APIs have dedicated support forums or help desks
- Stack Overflow for technical implementation questions
- GitHub repositories for API client libraries often have active communities
- Economic data communities on Reddit and specialized forums

---

**Last Updated**: 2025-11-22
**Version**: 1.0
