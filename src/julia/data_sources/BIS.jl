# SPDX-License-Identifier: PMPL-1.0-or-later

"""
BIS (Bank for International Settlements) Client

Provides access to financial and economic statistics from the Bank for International Settlements.

API Documentation: https://stats.bis.org/api-doc/v1/

Common Datasets:
- CNFS: Consolidated banking statistics
- CREDIT: Credit to the non-financial sector
- DSR: Debt service ratios
- LBS: Locational banking statistics
- CBPOL: Central bank policy rates
- EER: Effective exchange rates

Rate Limit: 60 requests/minute (reasonable)
API Key: Not required
"""

using HTTP
using JSON3
using Dates
using DataFrames

"""
    BISClient

Client for fetching data from BIS JSON API.

# Fields
- `base_url::String`: BIS API base URL
- `rate_limiter::RateLimiter`: Rate limiter (60/min)
- `cache::SQLiteCache`: Persistent cache
- `retry_config::RetryConfig`: Retry configuration
"""
struct BISClient
    base_url::String
    rate_limiter::RateLimiter
    cache::SQLiteCache
    retry_config::RetryConfig

    function BISClient(; cache_ttl::Int=86400)
        base_url = "https://stats.bis.org/api/v1"

        # Rate limit: 60 requests per minute
        rate_limiter = RateLimiter(60)

        cache = SQLiteCache(default_ttl=cache_ttl)
        retry_config = RetryConfig()

        new(base_url, rate_limiter, cache, retry_config)
    end
end

"""
    parse_bis_series_id(series_id::String)::Tuple{String, String, String}

Parse BIS series ID format: "DATASET:FREQUENCY:SERIES"

# Arguments
- `series_id::String`: BIS series identifier (e.g., "CBPOL:M:US")

# Returns
- `Tuple{String, String, String}`: (dataset, frequency, series)

# Example
```julia
dataset, freq, series = parse_bis_series_id("CBPOL:M:US")
# Returns: ("CBPOL", "M", "US")
```
"""
function parse_bis_series_id(series_id::String)::Tuple{String, String, String}
    parts = split(series_id, ":")

    if length(parts) != 3
        error("Invalid BIS series ID format. Expected 'DATASET:FREQUENCY:SERIES', got: $series_id")
    end

    dataset = parts[1]
    frequency = parts[2]
    series = parts[3]

    return (dataset, frequency, series)
end

"""
    parse_bis_period(period_str::String, frequency::String)::Date

Parse BIS period strings into Date.

# Arguments
- `period_str::String`: Period string (e.g., "2023-12", "2023-Q4", "2023")
- `frequency::String`: Frequency code (M=monthly, Q=quarterly, A=annual)

# Returns
- `Date`: Parsed date

# Example
```julia
date = parse_bis_period("2023-12", "M")  # Monthly
date = parse_bis_period("2023-Q4", "Q")  # Quarterly
date = parse_bis_period("2023", "A")     # Annual
```
"""
function parse_bis_period(period_str::String, frequency::String)::Date
    if frequency == "M"
        # Monthly: YYYY-MM
        return Date(period_str * "-01")
    elseif frequency == "Q"
        # Quarterly: YYYY-Q1, YYYY-Q2, etc.
        if occursin("Q", period_str)
            parts = split(period_str, "-Q")
            year = parse(Int, parts[1])
            quarter = parse(Int, parts[2])
            month = (quarter - 1) * 3 + 1
            return Date(year, month, 1)
        else
            # Alternative format: YYYYQQ
            year = parse(Int, period_str[1:4])
            quarter = parse(Int, period_str[6:6])
            month = (quarter - 1) * 3 + 1
            return Date(year, month, 1)
        end
    elseif frequency == "A"
        # Annual: YYYY
        return Date(parse(Int, period_str), 1, 1)
    else
        # Fallback: attempt standard date parsing
        try
            return Date(period_str)
        catch
            error("Unknown BIS period format: $period_str (frequency: $frequency)")
        end
    end
end

"""
    fetch_series(client::BISClient, series_id::String, start_date::Date, end_date::Date)::DataFrame

Fetch economic time series data from BIS.

# Arguments
- `client::BISClient`: BIS client instance
- `series_id::String`: BIS series identifier in format "DATASET:FREQUENCY:SERIES"
  (e.g., "CBPOL:M:US" for US policy rate monthly)
- `start_date::Date`: Start date for data
- `end_date::Date`: End date for data

# Returns
- `DataFrame`: Time series data with columns [:date, :value]

# Example
```julia
client = BISClient()

# Fetch US central bank policy rates (monthly)
data = fetch_series(client, "CBPOL:M:US", Date(2020, 1, 1), Date(2023, 12, 31))

# Fetch credit to non-financial sector
data = fetch_series(client, "CREDIT:Q:US:P", Date(2015, 1, 1), Date(2023, 12, 31))
```
"""
function fetch_series(client::BISClient, series_id::String, start_date::Date, end_date::Date)::DataFrame
    # Parse series ID
    dataset, frequency, series = parse_bis_series_id(series_id)

    # Check cache first
    cache_id = cache_key("bis", series_id, start_date, end_date)
    cached = get_cached(client.cache, cache_id)

    if cached !== nothing
        @debug "BIS: Cache hit" series_id
        return JSON3.read(cached, DataFrame)
    end

    @debug "BIS: Cache miss, fetching from API" series_id dataset frequency series

    # Rate limit
    if !wait_if_needed(client.rate_limiter)
        @warn "BIS: Rate limit wait timeout, attempting cache fallback"
        throw(ErrorException("Rate limit timeout"))
    end

    # Build request
    function fetch()
        # BIS API format: /data/{dataset}/{frequency}/{series}
        url = "$(client.base_url)/data/$(dataset)/$(frequency)/$(series)"

        params = Dict(
            "format" => "json",
            "detail" => "dataonly"
        )

        @debug "BIS: Making API request" url series_id

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
        json_data = JSON3.read(String(body))

        # Extract observations
        dates = Date[]
        values = Union{Float64, Missing}[]

        if haskey(json_data, :dataSets) && length(json_data.dataSets) > 0
            dataset_obj = json_data.dataSets[1]

            if haskey(dataset_obj, :observations)
                # Parse observations (array of arrays)
                for (time_idx_str, obs_array) in pairs(dataset_obj.observations)
                    # Get time period from structure
                    time_idx = parse(Int, time_idx_str) + 1  # Convert to 1-based

                    if haskey(json_data, :structure) &&
                       haskey(json_data.structure, :dimensions) &&
                       haskey(json_data.structure.dimensions, :observation)

                        obs_dims = json_data.structure.dimensions.observation

                        # Find time dimension
                        for dim in obs_dims
                            if dim.id == "TIME_PERIOD"
                                if time_idx <= length(dim.values)
                                    period_str = dim.values[time_idx].id

                                    # Parse date
                                    date_val = try
                                        parse_bis_period(period_str, frequency)
                                    catch e
                                        @warn "Failed to parse BIS period" period_str frequency exception=e
                                        continue
                                    end

                                    # Filter by date range
                                    if date_val >= start_date && date_val <= end_date
                                        # Extract value (first element of observation array)
                                        value_val = if length(obs_array) > 0
                                            obs_array[1]
                                        else
                                            missing
                                        end

                                        push!(dates, date_val)
                                        push!(values, value_val === nothing ? missing : Float64(value_val))
                                    end
                                end
                                break
                            end
                        end
                    end
                end
            end
        end

        # Sort by date
        if !isempty(dates)
            perm = sortperm(dates)
            df = DataFrame(date=dates[perm], value=values[perm])
        else
            df = DataFrame(date=Date[], value=Union{Float64, Missing}[])
        end

        # Cache successful response
        cache_data = JSON3.write(df)
        set_cached!(client.cache, cache_id, cache_data)

        @debug "BIS: Successfully fetched and cached data" rows=nrow(df)
        return df
    else
        # Return cached response
        return JSON3.read(String(body), DataFrame)
    end
end

"""
    search_series(client::BISClient, query::String; limit::Int=100)::Vector{Dict}

Search for BIS datasets and series.

# Arguments
- `client::BISClient`: BIS client instance
- `query::String`: Search query (dataset or series name)
- `limit::Int`: Maximum number of results (default: 100)

# Returns
- `Vector{Dict}`: Search results with metadata

# Example
```julia
client = BISClient()

# Search for credit datasets
results = search_series(client, "credit")

# Search for policy rates
results = search_series(client, "policy rate", limit=50)
```
"""
function search_series(client::BISClient, query::String; limit::Int=100)::Vector{Dict}
    # Check cache first
    cache_id = cache_key("bis_search", query, limit)
    cached = get_cached(client.cache, cache_id)

    if cached !== nothing
        @debug "BIS: Search cache hit" query
        return JSON3.read(cached, Vector{Dict})
    end

    @debug "BIS: Search cache miss" query

    # Rate limit
    if !wait_if_needed(client.rate_limiter)
        @warn "BIS: Rate limit wait timeout for search"
        throw(ErrorException("Rate limit timeout"))
    end

    # Build request
    function fetch()
        # BIS dataflow catalog
        url = "$(client.base_url)/dataflow"

        params = Dict(
            "format" => "json"
        )

        @debug "BIS: Making search API request" url query

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

        if haskey(json_data, :dataflows)
            for dataflow in json_data.dataflows
                # Filter by query
                name = get(dataflow, :name, "")
                id = get(dataflow, :id, "")
                description = get(dataflow, :description, "")

                if occursin(lowercase(query), lowercase(name)) ||
                   occursin(lowercase(query), lowercase(id)) ||
                   occursin(lowercase(query), lowercase(description))

                    push!(results, Dict(
                        "id" => id,
                        "name" => name,
                        "description" => description,
                        "source" => "bis"
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

        @debug "BIS: Search successful" results_count=length(results)
        return results
    else
        # Return cached results
        return JSON3.read(String(body), Vector{Dict})
    end
end

"""
    list_datasets(client::BISClient)::Vector{Dict}

List all available BIS datasets.

# Arguments
- `client::BISClient`: BIS client instance

# Returns
- `Vector{Dict}`: Dataset metadata

# Example
```julia
client = BISClient()
datasets = list_datasets(client)

for dataset in datasets
    println(dataset["id"], ": ", dataset["name"])
end
```
"""
function list_datasets(client::BISClient)::Vector{Dict}
    return search_series(client, "", limit=1000)
end

export BISClient, fetch_series, search_series, list_datasets, parse_bis_series_id
