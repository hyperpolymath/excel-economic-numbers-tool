# SPDX-License-Identifier: MPL-2.0

"""
Eurostat Client

Provides access to European statistical data via Eurostat's SDMX API.

API Documentation: https://ec.europa.eu/eurostat/web/sdmx-web-services/rest-sdmx-2.1

Common Datasets:
- namq_10_gdp: GDP and main components
- prc_hicp_midx: HICP inflation
- une_rt_m: Unemployment rate monthly
- ext_lt_introle: Interest rates
- bop_gdp6_q: Balance of payments

Rate Limit: 60 requests/minute (reasonable)
API Key: Not required
"""

using HTTP
using JSON3
using Dates
using LightXML
using DataFrames

"""
    EurostatClient

Client for fetching data from Eurostat SDMX API.

# Fields
- `base_url::String`: Eurostat API base URL
- `rate_limiter::RateLimiter`: Rate limiter (60/min)
- `cache::SQLiteCache`: Persistent cache
- `retry_config::RetryConfig`: Retry configuration
"""
struct EurostatClient
    base_url::String
    rate_limiter::RateLimiter
    cache::SQLiteCache
    retry_config::RetryConfig

    function EurostatClient(; cache_ttl::Int=86400)
        base_url = "https://ec.europa.eu/eurostat/api/dissemination/sdmx/2.1"

        # Rate limit: 60 requests per minute
        rate_limiter = RateLimiter(60)

        cache = SQLiteCache(default_ttl=cache_ttl)
        retry_config = RetryConfig()

        new(base_url, rate_limiter, cache, retry_config)
    end
end

"""
    parse_eurostat_sdmx(xml_content::String)::DataFrame

Parse Eurostat SDMX-ML format to DataFrame.

Eurostat uses SDMX 2.1 format which is similar to ECB but with different namespaces.

# Arguments
- `xml_content::String`: XML content in SDMX format

# Returns
- `DataFrame`: Time series data with columns [:date, :value]
"""
function parse_eurostat_sdmx(xml_content::String)::DataFrame
    doc = parse_string(xml_content)
    root = LightXML.root(doc)

    dates = Date[]
    values = Union{Float64, Missing}[]

    # Navigate SDMX structure: DataSet -> Series -> Obs
    # Eurostat SDMX namespaces: "message" -> "DataSet" -> "Series" -> "Obs"
    for dataset in get_elements_by_tagname(root, "DataSet")
        for series in get_elements_by_tagname(dataset, "Series")
            for obs in get_elements_by_tagname(series, "Obs")
                # Get observation date
                date_elem = find_element(obs, "ObsDimension")
                if date_elem !== nothing
                    date_str = attribute(date_elem, "value")

                    # Parse date - Eurostat uses various formats
                    date_val = try
                        parse_eurostat_date(date_str)
                    catch e
                        @warn "Failed to parse Eurostat date" date_str exception=e
                        continue
                    end

                    # Get observation value
                    value_elem = find_element(obs, "ObsValue")
                    if value_elem !== nothing
                        value_str = attribute(value_elem, "value")
                        value_val = try
                            parse(Float64, value_str)
                        catch
                            missing
                        end

                        push!(dates, date_val)
                        push!(values, value_val)
                    end
                end
            end
        end
    end

    free(doc)

    # Sort by date
    if !isempty(dates)
        perm = sortperm(dates)
        return DataFrame(date=dates[perm], value=values[perm])
    else
        return DataFrame(date=Date[], value=Union{Float64, Missing}[])
    end
end

"""
    parse_eurostat_date(date_str::String)::Date

Parse Eurostat date formats (daily, monthly, quarterly, annual).

# Supported formats
- YYYY-MM-DD: Daily
- YYYY-MM: Monthly
- YYYY-Qq: Quarterly (e.g., 2023-Q1)
- YYYY: Annual
"""
function parse_eurostat_date(date_str::String)::Date
    if occursin("Q", date_str)
        # Quarterly format: YYYY-Q1, YYYY-Q2, etc.
        parts = split(date_str, "-Q")
        year = parse(Int, parts[1])
        quarter = parse(Int, parts[2])
        month = (quarter - 1) * 3 + 1
        return Date(year, month, 1)
    elseif length(date_str) == 7 && occursin("-", date_str)
        # Monthly format: YYYY-MM
        return Date(date_str * "-01")
    elseif length(date_str) == 4
        # Annual format: YYYY
        return Date(date_str * "-01-01")
    elseif length(date_str) == 10
        # Daily format: YYYY-MM-DD
        return Date(date_str)
    else
        error("Unknown Eurostat date format: $date_str")
    end
end

"""
    fetch_series(client::EurostatClient, dataset_code::String, filter::String, start_date::Date, end_date::Date)::DataFrame

Fetch economic time series data from Eurostat.

# Arguments
- `client::EurostatClient`: Eurostat client instance
- `dataset_code::String`: Dataset identifier (e.g., "namq_10_gdp", "prc_hicp_midx")
- `filter::String`: SDMX filter expression (e.g., "Q.CLV10_MNAC.B1GQ.DE")
- `start_date::Date`: Start date for data
- `end_date::Date`: End date for data

# Returns
- `DataFrame`: Time series data with columns [:date, :value]

# Example
```julia
client = EurostatClient()

# Fetch quarterly German GDP (chain-linked volumes)
data = fetch_series(client, "namq_10_gdp", "Q.CLV10_MNAC.B1GQ.DE",
                   Date(2020, 1, 1), Date(2023, 12, 31))

# Fetch monthly HICP for Euro area
data = fetch_series(client, "prc_hicp_midx", "M.CP00.EA19",
                   Date(2020, 1, 1), Date(2023, 12, 31))
```
"""
function fetch_series(client::EurostatClient, dataset_code::String, filter::String,
                     start_date::Date, end_date::Date)::DataFrame
    # Check cache first
    cache_id = cache_key("eurostat", dataset_code, filter, start_date, end_date)
    cached = get_cached(client.cache, cache_id)

    if cached !== nothing
        @debug "Eurostat: Cache hit" dataset_code filter
        return JSON3.read(cached, DataFrame)
    end

    @debug "Eurostat: Cache miss, fetching from API" dataset_code filter

    # Rate limit
    if !wait_if_needed(client.rate_limiter)
        @warn "Eurostat: Rate limit wait timeout, attempting cache fallback"
        throw(ErrorException("Rate limit timeout"))
    end

    # Build request
    function fetch()
        # Eurostat SDMX API format: /data/{dataflow}/{filter}?startPeriod=YYYY-MM-DD&endPeriod=YYYY-MM-DD
        url = "$(client.base_url)/data/$(dataset_code)/$(filter)"

        params = Dict(
            "startPeriod" => Dates.format(start_date, "yyyy-mm-dd"),
            "endPeriod" => Dates.format(end_date, "yyyy-mm-dd"),
            "format" => "sdmx-ml"  # SDMX-ML XML format
        )

        @debug "Eurostat: Making API request" url dataset_code filter

        response = HTTP.get(url, query=params)

        if response.status != 200
            throw(HTTP.Exceptions.StatusError(response.status, response))
        end

        return response.body
    end

    # Execute with retry and cache fallback
    body, from_cache = with_retry_and_cache(fetch, client.cache, cache_id, client.retry_config)

    if !from_cache
        # Parse fresh response
        xml_content = String(body)
        df = parse_eurostat_sdmx(xml_content)

        # Cache successful response
        cache_data = JSON3.write(df)
        set_cached!(client.cache, cache_id, cache_data)

        @debug "Eurostat: Successfully fetched and cached data" rows=nrow(df)
        return df
    else
        # Return cached response
        return JSON3.read(String(body), DataFrame)
    end
end

"""
    search_series(client::EurostatClient, query::String; limit::Int=100)::Vector{Dict}

Search for Eurostat datasets and series.

# Arguments
- `client::EurostatClient`: Eurostat client instance
- `query::String`: Search query (dataset or series name)
- `limit::Int`: Maximum number of results (default: 100)

# Returns
- `Vector{Dict}`: Search results with metadata

# Example
```julia
client = EurostatClient()

# Search for GDP datasets
results = search_series(client, "GDP")

# Search for unemployment data
results = search_series(client, "unemployment", limit=50)
```
"""
function search_series(client::EurostatClient, query::String; limit::Int=100)::Vector{Dict}
    # Check cache first
    cache_id = cache_key("eurostat_search", query, limit)
    cached = get_cached(client.cache, cache_id)

    if cached !== nothing
        @debug "Eurostat: Search cache hit" query
        return JSON3.read(cached, Vector{Dict})
    end

    @debug "Eurostat: Search cache miss" query

    # Rate limit
    if !wait_if_needed(client.rate_limiter)
        @warn "Eurostat: Rate limit wait timeout for search"
        throw(ErrorException("Rate limit timeout"))
    end

    # Build request
    function fetch()
        # Eurostat search uses dataflow catalog
        url = "$(client.base_url)/dataflow/ESTAT/all/latest"

        params = Dict(
            "format" => "json"
        )

        @debug "Eurostat: Making search API request" url query

        response = HTTP.get(url, query=params)

        if response.status != 200
            throw(HTTP.Exceptions.StatusError(response.status, response))
        end

        return response.body
    end

    # Execute with retry
    body, from_cache = with_retry_and_cache(fetch, client.cache, cache_id, client.retry_config)

    if !from_cache
        # Parse JSON response
        json_data = JSON3.read(String(body))

        # Extract dataflows
        results = Dict[]

        if haskey(json_data, :data) && haskey(json_data.data, :dataflows)
            for dataflow in json_data.data.dataflows
                # Filter by query
                name = get(dataflow, :name, "")
                id = get(dataflow, :id, "")

                if occursin(lowercase(query), lowercase(name)) || occursin(lowercase(query), lowercase(id))
                    push!(results, Dict(
                        "id" => id,
                        "name" => name,
                        "description" => get(dataflow, :description, ""),
                        "source" => "eurostat"
                    ))

                    if length(results) >= limit
                        break
                    end
                end
            end
        end

        # Cache results
        cache_data = JSON3.write(results)
        set_cached!(client.cache, cache_id, cache_data)

        @debug "Eurostat: Search successful" results_count=length(results)
        return results
    else
        # Return cached results
        return JSON3.read(String(body), Vector{Dict})
    end
end

"""
    list_datasets(client::EurostatClient; limit::Int=1000)::Vector{Dict}

List available Eurostat datasets.

# Arguments
- `client::EurostatClient`: Eurostat client instance
- `limit::Int`: Maximum number of datasets (default: 1000)

# Returns
- `Vector{Dict}`: Dataset metadata

# Example
```julia
client = EurostatClient()
datasets = list_datasets(client, limit=100)
```
"""
function list_datasets(client::EurostatClient; limit::Int=1000)::Vector{Dict}
    return search_series(client, "", limit=limit)
end

export EurostatClient, fetch_series, search_series, list_datasets
