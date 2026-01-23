"""
OECD (Organisation for Economic Co-operation and Development) Client

Provides access to OECD statistical data including national accounts, economic indicators,
employment, and more.

API Documentation: https://data.oecd.org/api/
SDMX-JSON Format: https://github.com/sdmx-twg/sdmx-json

Rate Limit: 60 requests/minute (no API key required)
Common Datasets:
- QNA: Quarterly National Accounts
- MEI: Main Economic Indicators
- KEI: Key Short-Term Economic Indicators
"""

using HTTP
using JSON3
using Dates
using DataFrames

"""
    OECDClient

Client for fetching data from OECD Stats API.

# Fields
- `base_url::String`: OECD SDMX-JSON API base URL
- `rate_limiter::RateLimiter`: Rate limiter (60 requests/min)
- `cache::SQLiteCache`: Persistent cache
- `retry_config::RetryConfig`: Retry configuration
"""
struct OECDClient
    base_url::String
    rate_limiter::RateLimiter
    cache::SQLiteCache
    retry_config::RetryConfig

    function OECDClient(; cache_ttl::Int=86400)
        base_url = "https://stats.oecd.org/SDMX-JSON/data"

        # OECD rate limit: 60 requests per minute, no API key required
        rate_limiter = RateLimiter(60)

        cache = SQLiteCache(default_ttl=cache_ttl)
        retry_config = RetryConfig()

        new(base_url, rate_limiter, cache, retry_config)
    end
end

"""
    parse_sdmx_json(data::JSON3.Object)::DataFrame

Parse OECD SDMX-JSON format into a DataFrame.

SDMX-JSON structure:
- dataSets[0].series contains time series
- structure.dimensions contains dimension metadata
- Each series has observations array

# Arguments
- `data::JSON3.Object`: Parsed SDMX-JSON response

# Returns
- `DataFrame`: Time series data with columns [:date, :value]
"""
function parse_sdmx_json(data::JSON3.Object)::DataFrame
    dates = Date[]
    values = Float64[]

    # Extract time dimension from structure
    time_values = nothing
    for dim in data.structure.dimensions.observation
        if haskey(dim, :id) && dim.id == "TIME_PERIOD"
            time_values = dim.values
            break
        end
    end

    if time_values === nothing
        throw(ErrorException("TIME_PERIOD dimension not found in SDMX-JSON response"))
    end

    # Extract data from first dataset
    if !haskey(data, :dataSets) || isempty(data.dataSets)
        return DataFrame(date=Date[], value=Float64[])
    end

    dataset = first(data.dataSets)

    # SDMX-JSON can have series-level or dataset-level observations
    if haskey(dataset, :series)
        # Series-level observations
        for (series_key, series_data) in pairs(dataset.series)
            if haskey(series_data, :observations)
                for (obs_key, obs_value) in pairs(series_data.observations)
                    # obs_key is the time index
                    time_idx = parse(Int, String(obs_key)) + 1  # Convert to 1-indexed
                    if time_idx <= length(time_values)
                        date_str = time_values[time_idx].id
                        push!(dates, parse_oecd_date(date_str))
                        # obs_value is typically an array [value, ...]
                        value = obs_value isa Array ? first(obs_value) : obs_value
                        push!(values, value === nothing ? NaN : Float64(value))
                    end
                end
            end
        end
    elseif haskey(dataset, :observations)
        # Dataset-level observations
        for (obs_key, obs_value) in pairs(dataset.observations)
            # Parse the composite key (e.g., "0:0:0:5" where last is time index)
            key_parts = split(String(obs_key), ':')
            time_idx = parse(Int, last(key_parts)) + 1  # Convert to 1-indexed
            if time_idx <= length(time_values)
                date_str = time_values[time_idx].id
                push!(dates, parse_oecd_date(date_str))
                value = obs_value isa Array ? first(obs_value) : obs_value
                push!(values, value === nothing ? NaN : Float64(value))
            end
        end
    end

    # Sort by date
    perm = sortperm(dates)
    return DataFrame(date=dates[perm], value=values[perm])
end

"""
    parse_oecd_date(date_str::String)::Date

Parse OECD date formats into Julia Date.

Common formats:
- "2023-Q4" -> quarterly
- "2023-12" -> monthly
- "2023" -> yearly

# Arguments
- `date_str::String`: OECD date string

# Returns
- `Date`: Parsed date
"""
function parse_oecd_date(date_str::String)::Date
    # Quarterly: "2023-Q4"
    if occursin(r"^\d{4}-Q[1-4]$", date_str)
        year = parse(Int, date_str[1:4])
        quarter = parse(Int, date_str[end])
        month = (quarter - 1) * 3 + 1
        return Date(year, month, 1)
    end

    # Monthly: "2023-12"
    if occursin(r"^\d{4}-\d{2}$", date_str)
        return Date(date_str * "-01")
    end

    # Yearly: "2023"
    if occursin(r"^\d{4}$", date_str)
        return Date(date_str * "-01-01")
    end

    # ISO format: "2023-12-31"
    try
        return Date(date_str)
    catch
        throw(ArgumentError("Unsupported OECD date format: $date_str"))
    end
end

"""
    fetch_series(client::OECDClient, dataset::String, filter_expr::String="all", start_date::Union{Date, Nothing}=nothing, end_date::Union{Date, Nothing}=nothing)::DataFrame

Fetch economic time series data from OECD.

# Arguments
- `client::OECDClient`: OECD client instance
- `dataset::String`: OECD dataset code (e.g., "QNA", "MEI")
- `filter_expr::String`: SDMX filter expression (default: "all"). Format: "LOCATION.SUBJECT.MEASURE.FREQUENCY"
- `start_date::Union{Date, Nothing}`: Start date for data (optional)
- `end_date::Union{Date, Nothing}`: End date for data (optional)

# Returns
- `DataFrame`: Time series data with columns [:date, :value]

# Examples
```julia
client = OECDClient()

# Quarterly National Accounts - GDP for USA
data = fetch_series(client, "QNA", "USA.B1_GE.CUR.Q")

# Main Economic Indicators - CPI for all countries
data = fetch_series(client, "MEI", "all.CPALTT01.IXOB.M")

# With date range
data = fetch_series(client, "QNA", "USA.B1_GE.CUR.Q", Date(2020, 1, 1), Date(2023, 12, 31))
```
"""
function fetch_series(
    client::OECDClient,
    dataset::String,
    filter_expr::String="all",
    start_date::Union{Date, Nothing}=nothing,
    end_date::Union{Date, Nothing}=nothing
)::DataFrame
    # Build cache key
    key = cache_key("oecd", "$dataset/$filter_expr",
                    something(start_date, Date(1900, 1, 1)),
                    something(end_date, Date(2100, 12, 31)))

    # Check cache first
    cached = get_cached(client.cache, key)

    if cached !== nothing
        @debug "OECD: Cache hit" dataset filter_expr
        return JSON3.read(cached, DataFrame)
    end

    @debug "OECD: Cache miss, fetching from API" dataset filter_expr

    # Rate limit
    if !wait_if_needed(client.rate_limiter)
        @warn "OECD: Rate limit wait timeout, attempting cache fallback"
        throw(ErrorException("Rate limit timeout"))
    end

    # Build request
    function fetch()
        # OECD URL format: /dataset/filter_expr/all
        url = "$(client.base_url)/$dataset/$filter_expr/all"

        # Build query parameters
        params = Dict{String, String}()

        # Add date filters if provided
        if start_date !== nothing || end_date !== nothing
            start_str = start_date !== nothing ? Dates.format(start_date, "yyyy-mm-dd") : ""
            end_str = end_date !== nothing ? Dates.format(end_date, "yyyy-mm-dd") : ""

            if start_str != "" && end_str != ""
                params["startTime"] = start_str
                params["endTime"] = end_str
            elseif start_str != ""
                params["startTime"] = start_str
            elseif end_str != ""
                params["endTime"] = end_str
            end
        end

        @debug "OECD: Making API request" url dataset filter_expr

        response = if isempty(params)
            HTTP.get(url, ["Accept" => "application/vnd.sdmx.data+json;version=1.0.0-wd"])
        else
            HTTP.get(url, ["Accept" => "application/vnd.sdmx.data+json;version=1.0.0-wd"], query=params)
        end

        if response.status != 200
            throw(HTTP.Exceptions.StatusError(response.status, response))
        end

        return response.body
    end

    # Execute with retry and cache fallback
    body, from_cache = with_retry_and_cache(fetch, client.cache, key, client.retry_config)

    if !from_cache
        # Parse fresh response
        data = JSON3.read(body)

        # Convert SDMX-JSON to DataFrame
        df = parse_sdmx_json(data)

        # Cache the result
        set_cached(
            client.cache,
            key,
            JSON3.write(df),
            metadata=Dict("source" => "oecd", "dataset" => dataset, "filter" => filter_expr)
        )

        return df
    else
        # From cache after retry failure
        return body
    end
end

"""
    search_series(client::OECDClient, dataset::String; limit::Int=100)::Vector{Dict}

Search for available series in an OECD dataset.

Note: OECD does not provide a traditional search API. This function returns
information about the dataset structure and dimensions.

# Arguments
- `client::OECDClient`: OECD client instance
- `dataset::String`: OECD dataset code (e.g., "QNA", "MEI")
- `limit::Int`: Maximum results to return (default: 100)

# Returns
- `Vector{Dict}`: Dataset structure information

# Example
```julia
client = OECDClient()
info = search_series(client, "QNA")
```
"""
function search_series(client::OECDClient, dataset::String; limit::Int=100)::Vector{Dict}
    # Check cache
    key = cache_key("oecd", "structure:$dataset")
    cached = get_cached(client.cache, key)

    if cached !== nothing
        @debug "OECD: Structure cache hit" dataset
        return JSON3.read(cached)
    end

    # Rate limit
    if !wait_if_needed(client.rate_limiter)
        throw(ErrorException("Rate limit timeout"))
    end

    # Fetch dataset structure
    url = "$(client.base_url)/$dataset/all/all"

    @debug "OECD: Fetching dataset structure" url dataset

    response = HTTP.get(url, ["Accept" => "application/vnd.sdmx.data+json;version=1.0.0-wd"])

    if response.status != 200
        throw(HTTP.Exceptions.StatusError(response.status, response))
    end

    data = JSON3.read(response.body)

    # Extract dimension information
    results = Dict{String, Any}[]

    if haskey(data, :structure) && haskey(data.structure, :dimensions)
        for dim_group in [:series, :observation]
            if haskey(data.structure.dimensions, dim_group)
                for dim in data.structure.dimensions[dim_group]
                    dim_info = Dict(
                        "id" => dim.id,
                        "name" => get(dim, :name, ""),
                        "type" => String(dim_group),
                        "values" => []
                    )

                    # Add available values for this dimension
                    if haskey(dim, :values) && length(results) < limit
                        for val in dim.values
                            if length(dim_info["values"]) < 20  # Limit values per dimension
                                push!(dim_info["values"], Dict(
                                    "id" => val.id,
                                    "name" => get(val, :name, val.id)
                                ))
                            end
                        end
                    end

                    push!(results, dim_info)

                    if length(results) >= limit
                        break
                    end
                end
            end

            if length(results) >= limit
                break
            end
        end
    end

    # Cache results
    set_cached(
        client.cache,
        key,
        JSON3.write(results),
        ttl=3600,  # Cache structure for 1 hour
        metadata=Dict("source" => "oecd", "type" => "structure", "dataset" => dataset)
    )

    return results
end

"""
    get_dataset_info(client::OECDClient, dataset::String)::Dict

Get metadata for a specific OECD dataset.

# Arguments
- `client::OECDClient`: OECD client instance
- `dataset::String`: OECD dataset code

# Returns
- `Dict`: Dataset metadata

# Example
```julia
client = OECDClient()
info = get_dataset_info(client, "QNA")
```
"""
function get_dataset_info(client::OECDClient, dataset::String)::Dict
    # Rate limit
    if !wait_if_needed(client.rate_limiter)
        throw(ErrorException("Rate limit timeout"))
    end

    # Fetch dataset structure
    url = "$(client.base_url)/$dataset/all/all"
    response = HTTP.get(url, ["Accept" => "application/vnd.sdmx.data+json;version=1.0.0-wd"])

    data = JSON3.read(response.body)

    result = Dict(
        "dataset" => dataset,
        "name" => get(get(data, :structure, Dict()), :name, dataset),
        "dimensions" => Dict{String, Any}()
    )

    # Extract dimensions
    if haskey(data, :structure) && haskey(data.structure, :dimensions)
        for dim_group in [:series, :observation]
            if haskey(data.structure.dimensions, dim_group)
                for dim in data.structure.dimensions[dim_group]
                    result["dimensions"][dim.id] = Dict(
                        "name" => get(dim, :name, ""),
                        "role" => String(dim_group),
                        "count" => haskey(dim, :values) ? length(dim.values) : 0
                    )
                end
            end
        end
    end

    return result
end
