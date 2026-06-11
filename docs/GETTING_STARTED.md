<!--
SPDX-License-Identifier: MPL-2.0
Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-->
# Getting Started with Economic Toolkit v10.0

Welcome! This guide will help you get up and running with Economic Toolkit in under 10 minutes.

## Choose Your Platform

- [Python](#python-quick-start)
- [R](#r-quick-start)
- [Excel](#excel-quick-start)
- [LibreOffice](#libreoffice-quick-start)
- [Google Sheets](#google-sheets-quick-start)
- [REST API](#rest-api-quick-start)

---

## Python Quick Start

### Installation

```bash
pip install economic-toolkit
```

### Basic Usage

```python
from economic_toolkit import FRED, WorldBank, gdp_growth, gini_coefficient

# Fetch data from FRED
fred = FRED()
gdp_data = fred.fetch("GDPC1", start_date="2020-01-01", end_date="2023-12-31")
print(f"Fetched {len(gdp_data['observations'])} GDP observations")

# Calculate growth rates
values = [obs['value'] for obs in gdp_data['observations']]
growth = gdp_growth(values)
print(f"GDP growth rates: {growth}")

# Calculate inequality
incomes = [20000, 30000, 40000, 50000, 100000, 500000]
gini = gini_coefficient(incomes)
print(f"Gini coefficient: {gini:.3f}")
```

### Next Steps (Python)

- 📖 Read the [Python API Reference](api/python_api.md)
- 💡 See more [Python Examples](../examples/python_api_usage.py)
- 🔗 Learn about [Data Sources](api/data_sources.md)

---

## R Quick Start

### Installation

```r
install.packages("economic.toolkit")
```

### Basic Usage

```r
library(economic.toolkit)

# Fetch data from World Bank
wb <- WorldBank()
data <- wb$fetch("USA", start_date = "2020-01-01", end_date = "2023-12-31")
print(paste("Fetched", length(data$observations), "observations"))

# Calculate growth rates
values <- sapply(data$observations, function(x) x$value)
growth <- gdp_growth(values)
print(paste("Growth rates:", paste(round(growth, 2), collapse=", ")))

# Visualize Lorenz curve
incomes <- c(20000, 30000, 40000, 50000, 100000, 500000)
curve <- lorenz_curve(incomes)

library(ggplot2)
df <- data.frame(
  population = curve$cumulative_population,
  income = curve$cumulative_income
)
ggplot(df, aes(x = population, y = income)) +
  geom_line(color = "blue", size = 1) +
  geom_abline(intercept = 0, slope = 1, linetype = "dashed") +
  labs(title = "Lorenz Curve", x = "Cumulative Population", y = "Cumulative Income")
```

### Next Steps (R)

- 📖 Read the [R Package Documentation](api/r_api.md)
- 💡 See more [R Examples](../examples/r_api_usage.R)
- 📊 Learn about [Visualization Options](api/visualization.md)

---

## Excel Quick Start

### Installation

1. Download the latest `.xlsm` add-in from [GitHub Releases](https://github.com/hyperpolymath/excel-economic-numbers-tool/releases)
2. Open Excel
3. Go to **Insert** → **Get Add-ins** → **Upload My Add-in**
4. Select the downloaded `EconomicToolkit.xlsm` file
5. The Economic Toolkit ribbon will appear

### Basic Usage

In any Excel cell, use these formulas:

```excel
=ECON.FRED("UNRATE", "2020-01-01", "2023-12-31")
=ECON.WORLDBANK("USA", "NY.GDP.MKTP.CD", 2020, 2023)
=ECON.GINI(A1:A100)
=ECON.GROWTH_RATE(B1:B50)
=ECON.CAGR(100, 150, 5)
```

### Configuration

1. Click **Economic Toolkit** ribbon → **Settings**
2. (Optional) Enter API keys for FRED, BEA, Census
3. Configure cache settings
4. Set default date ranges

### Next Steps (Excel)

- 📖 Read the [Excel Formula Reference](api/excel_formulas.md)
- 💡 Download [Example Workbooks](../examples/excel/)
- 🎓 Watch [Video Tutorials](https://youtube.com/economictoolkit)

---

## LibreOffice Quick Start

### Installation

1. Download the `.oxt` extension from [GitHub Releases](https://github.com/hyperpolymath/excel-economic-numbers-tool/releases)
2. Open LibreOffice Calc
3. Go to **Tools** → **Extension Manager**
4. Click **Add** and select the downloaded `.oxt` file
5. Restart LibreOffice

### Basic Usage

Same formulas as Excel (prefix with `=`):

```
=ECON.FRED("GDPC1", "2020-01-01", "2023-12-31")
=ECON.GINI(A1:A100)
```

### Next Steps (LibreOffice)

- 📖 Read the [LibreOffice Guide](api/libreoffice_guide.md)
- 💡 See [Example Spreadsheets](../examples/libreoffice/)

---

## Google Sheets Quick Start

### Installation

1. Visit [Google Workspace Marketplace](https://workspace.google.com/marketplace)
2. Search for "Economic Toolkit"
3. Click **Install**
4. Grant necessary permissions

### Basic Usage

In any cell:

```
=ECON_FRED("UNRATE", "2020-01-01", "2023-12-31")
=ECON_GINI(A1:A100)
=ECON_GROWTH_RATE(B1:B50)
```

### Configuration

1. **Extensions** → **Economic Toolkit** → **Settings**
2. Enter REST API URL (default: http://localhost:8080)
3. (Optional) Enter API key

### Next Steps (Google Sheets)

- 📖 Read the [Google Sheets Guide](api/google_sheets_guide.md)
- 💡 See [Example Sheets](https://drive.google.com/economictoolkit-examples)

---

## REST API Quick Start

### Docker Deployment

```bash
# Pull and run
docker pull ghcr.io/hyperpolymath/excel-economic-numbers-tool:v10.0.0
docker run -d -p 8080:8080 --name economic-toolkit \
  ghcr.io/hyperpolymath/excel-economic-numbers-tool:v10.0.0

# Check health
curl http://localhost:8080/health
```

### API Usage

```bash
# List data sources
curl http://localhost:8080/api/v1/sources

# Fetch FRED data
curl "http://localhost:8080/api/v1/sources/fred/series/UNRATE?start=2020-01-01&end=2023-12-31"

# With authentication
curl -H "Authorization: Bearer YOUR_API_KEY" \
  "http://localhost:8080/api/v1/sources/fred/series/GDPC1"
```

### Next Steps (REST API)

- 📖 Read the [REST API Documentation](api/rest_api.md)
- 🔐 Learn about [Authentication](api/authentication.md)
- 📊 Explore [GraphQL API](api/graphql_api.md)

---

## Common Tasks

### Getting an API Key

Some data sources require API keys:

1. **FRED**: Register at https://fred.stlouisfed.org/docs/api/api_key.html
2. **BEA**: Register at https://apps.bea.gov/API/signup/
3. **Census**: Register at https://api.census.gov/data/key_signup.html

### Configuring Cache

Speed up repeated queries by enabling caching:

**Python:**
```python
from economic_toolkit import EconomicToolkit

client = EconomicToolkit(
    mode="rest",
    api_url="http://localhost:8080",
    cache_enabled=True,
    cache_ttl=3600  # 1 hour
)
```

**R:**
```r
client <- EconomicToolkit(
  cache_enabled = TRUE,
  cache_ttl = 3600
)
```

### Working Offline

Economic Toolkit can cache data for offline use:

1. Fetch data while online
2. Cache is automatically saved to SQLite database
3. Subsequent requests use cached data within TTL
4. Manually refresh with `force_refresh=True`

---

## Getting Help

- 📖 **Documentation**: https://hyperpolymath.github.io/excel-economic-numbers-tool
- 💬 **Community Forum**: https://github.com/hyperpolymath/excel-economic-numbers-tool/discussions
- 🐛 **Report Issues**: https://github.com/hyperpolymath/excel-economic-numbers-tool/issues
- 📧 **Email Support**: support@economictoolkit.org

---

## Next Steps

- 🎓 Take the [Interactive Tutorial](tutorials/interactive_tutorial.md)
- 📚 Browse [Example Gallery](../examples/)
- 🎯 Join the [Certification Program](certification/program.md)
- 🤝 Become a [Contributor](governance/CONTRIBUTING.adoc)

**Welcome to the Economic Toolkit community!** 🎉
