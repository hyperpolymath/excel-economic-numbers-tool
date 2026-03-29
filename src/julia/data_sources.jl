# SPDX-License-Identifier: PMPL-1.0-or-later
# SPDX-FileCopyrightText: 2024-2026 Hyperpolymath Contributors

"""
    DataSourceBase

Abstract base type for all economic data source clients.
Each concrete subtype must define `source_id` and `source_name` methods.
"""
abstract type DataSourceBase end

"""
    source_id(ds::DataSourceBase) -> String

Return the data source identifier string (e.g. "fred", "worldbank").
"""
function source_id end

"""
    source_name(ds::DataSourceBase) -> String

Return the human-readable data source name.
"""
function source_name end

"""
    datasource_fetch(ds, series_id; start_date=nothing, end_date=nothing)

Fetch series data from a data source.

# Arguments
- `ds::DataSourceBase`: The data source client
- `series_id::String`: Series identifier
- `start_date::Union{Date, Nothing}`: Optional start date
- `end_date::Union{Date, Nothing}`: Optional end date

# Returns
A `Dict` with series data.
"""
function datasource_fetch(
    ds::DataSourceBase,
    series_id::String;
    start_date::Union{Date, Nothing} = nothing,
    end_date::Union{Date, Nothing} = nothing,
)::Dict
    return fetch_series(ds.client, source_id(ds), series_id; start_date, end_date)
end

"""
    datasource_search(ds, query)

Search for series within a data source.

# Arguments
- `ds::DataSourceBase`: The data source client
- `query::String`: Search query string

# Returns
A `Vector` of matching series.
"""
function datasource_search(ds::DataSourceBase, query::String)::Vector
    return search_series(ds.client, source_id(ds), query)
end

# --- Concrete data source types ---

"""
    FRED <: DataSourceBase

Federal Reserve Economic Data (FRED) client.
"""
struct FRED <: DataSourceBase
    client::EconomicClient
    FRED(; client::EconomicClient = EconomicClient()) = new(client)
end
source_id(::FRED) = "fred"
source_name(::FRED) = "Federal Reserve Economic Data"

"""
    WorldBank <: DataSourceBase

World Bank data client.
"""
struct WorldBank <: DataSourceBase
    client::EconomicClient
    WorldBank(; client::EconomicClient = EconomicClient()) = new(client)
end
source_id(::WorldBank) = "worldbank"
source_name(::WorldBank) = "World Bank"

"""
    IMF <: DataSourceBase

International Monetary Fund data client.
"""
struct IMF <: DataSourceBase
    client::EconomicClient
    IMF(; client::EconomicClient = EconomicClient()) = new(client)
end
source_id(::IMF) = "imf"
source_name(::IMF) = "International Monetary Fund"

"""
    OECD <: DataSourceBase

OECD data client.
"""
struct OECD <: DataSourceBase
    client::EconomicClient
    OECD(; client::EconomicClient = EconomicClient()) = new(client)
end
source_id(::OECD) = "oecd"
source_name(::OECD) = "OECD"

"""
    ECB <: DataSourceBase

European Central Bank data client.
"""
struct ECB <: DataSourceBase
    client::EconomicClient
    ECB(; client::EconomicClient = EconomicClient()) = new(client)
end
source_id(::ECB) = "ecb"
source_name(::ECB) = "European Central Bank"

"""
    BEA <: DataSourceBase

Bureau of Economic Analysis data client.
"""
struct BEA <: DataSourceBase
    client::EconomicClient
    BEA(; client::EconomicClient = EconomicClient()) = new(client)
end
source_id(::BEA) = "bea"
source_name(::BEA) = "Bureau of Economic Analysis"

"""
    Census <: DataSourceBase

US Census Bureau data client.
"""
struct Census <: DataSourceBase
    client::EconomicClient
    Census(; client::EconomicClient = EconomicClient()) = new(client)
end
source_id(::Census) = "census"
source_name(::Census) = "US Census Bureau"

"""
    Eurostat <: DataSourceBase

Eurostat data client.
"""
struct Eurostat <: DataSourceBase
    client::EconomicClient
    Eurostat(; client::EconomicClient = EconomicClient()) = new(client)
end
source_id(::Eurostat) = "eurostat"
source_name(::Eurostat) = "Eurostat"

"""
    BIS <: DataSourceBase

Bank for International Settlements data client.
"""
struct BIS <: DataSourceBase
    client::EconomicClient
    BIS(; client::EconomicClient = EconomicClient()) = new(client)
end
source_id(::BIS) = "bis"
source_name(::BIS) = "Bank for International Settlements"

"""
    DBnomics <: DataSourceBase

DBnomics aggregated data client.
"""
struct DBnomics <: DataSourceBase
    client::EconomicClient
    DBnomics(; client::EconomicClient = EconomicClient()) = new(client)
end
source_id(::DBnomics) = "dbnomics"
source_name(::DBnomics) = "DBnomics"
