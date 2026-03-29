# SPDX-License-Identifier: PMPL-1.0-or-later
# SPDX-FileCopyrightText: 2024-2026 Hyperpolymath Contributors

"""
    EconomicToolkit

Julia module providing access to economic data sources and analysis functions.
Replaces the Python economic_toolkit package.
"""
module EconomicToolkit

using HTTP
using JSON3
using Dates

const VERSION = "2.1.0"
const AUTHOR = "Hyperpolymath Contributors"
const LICENSE = "PMPL-1.0-or-later"

include("client.jl")
include("data_sources.jl")
include("formulas.jl")

export EconomicClient,
       fetch_series, search_series, list_sources, health,
       # Data sources
       DataSourceBase, FRED, WorldBank, IMF, OECD, ECB, BEA, Census, Eurostat, BIS, DBnomics,
       source_id, source_name, datasource_fetch, datasource_search,
       # Formulas
       elasticity, gdp_growth, gini_coefficient, lorenz_curve, cagr, growth_rate

end # module EconomicToolkit
