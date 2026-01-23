"""
DBnomics (Database of Macroeconomic Statistics) Client

Provides access to 700+ million economic time series from 70+ data providers worldwide.

API Documentation: https://api.db.nomics.world/v22/apidocs

Rate Limit: 500 requests/minute (no API key required)
"""

using HTTP
using JSON3
using Dates

"""
    DBnomicsClient

Client for fetching data from DBnomics API.

# Fields
- `base_url::String`: DBnomics API base URL
- `rate_limiter::RateLimiter`: Rate limiter (500/min)
- `cache::SQLiteCache`: Persistent cache
- `retry_config::RetryConfig`: Retry configuration
"""
struct DBnomicsClient
    base_url::String
    rate_limiter::RateLimiter
    cache::SQLiteCache
    retry_config::RetryConfig

    function DBnomicsClient(;
        cache_ttl::Int=86400
    )
        base_url = "https://api.db.nomics.world/v22"

        # DBnomics has higher rate limits (500/min)
        rate_limiter = RateLimiter(500)

        cache = SQLiteCache(default_ttl=cache_ttl)
        retry_config = RetryConfig()

        new(base_url, rate_limiter, cache, retry_config)
    end
end

"""
    fetch_series(client::DBnomicsClient, provider::String, dataset::String, series::String, start_date::Date, end_date::Date)::DataFrame

Fetch economic time series data from DBnomics.

# Arguments
- `client::DBnomicsClient`: DBnomics client instance
- `provider::String`: Data provider code (e.g., "FRED", "ECB", "IMF")
- `dataset::String`: Dataset code within the provider
- `series::String`: Series code within the dataset
- `start_date::Date`: Start date for data
- `end_date::Date`: End date for data

# Returns
- `DataFrame`: Time series data with columns [:date, :value]

# Example
```julia
client = DBnomicsClient()
data = fetch_series(client, "FRED", "series", "GDPC1", Date(2020, 1, 1), Date(2023, 12, 31))
```
"""
function fetch_series(client::DBnomicsClient, provider::String, dataset::String, series::String, start_date::Date, end_date::Date)::DataFrame
    # Check cache first
    series_id = "$provider/$dataset/$series"
    key = cache_key("dbnomics", series_id, start_date, end_date)
    cached = get_cached(client.cache, key)

    if cached !== nothing
        @debug "DBnomics: Cache hit" series_id
        return JSON3.read(cached, DataFrame)
    end

    @debug "DBnomics: Cache miss, fetching from API" series_id

    # Rate limit
    if !wait_if_needed(client.rate_limiter)
        @warn "DBnomics: Rate limit wait timeout, attempting cache fallback"
        # Try to return slightly older cached data
        throw(ErrorException("Rate limit timeout"))
    end

    # Build request
    function fetch()
        # DBnomics API format: /series/{provider}/{dataset}/{series}
        url = "$(client.base_url)/series/$provider/$dataset/$series"

        params = Dict(
            "observations" => "1",
            "format" => "json"
        )

        @debug "DBnomics: Making API request" url series_id

        response = HTTP.get(url, query=params)

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

        # Convert to DataFrame
        observations = data.series.observations

        # Filter by date range and convert to DataFrame
        dates = Date[]
        values = Float64[]

        for obs in observations
            obs_date = Date(obs.period)
            if obs_date >= start_date && obs_date <= end_date
                push!(dates, obs_date)
                push!(values, obs.value === nothing ? missing : Float64(obs.value))
            end
        end

        df = DataFrame(date=dates, value=values)

        # Cache the result
        set_cached(
            client.cache,
            key,
            JSON3.write(df),
            metadata=Dict(
                "source" => "dbnomics",
                "provider" => provider,
                "dataset" => dataset,
                "series" => series
            )
        )

        return df
    else
        # From cache after retry failure
        return body
    end
end

"""
    search_series(client::DBnomicsClient, query::String; limit::Int=100, provider::Union{String, Nothing}=nothing)::Vector{Dict}

Search for DBnomics series by keyword.

# Arguments
- `client::DBnomicsClient`: DBnomics client instance
- `query::String`: Search query
- `limit::Int`: Maximum results to return (default: 100)
- `provider::Union{String, Nothing}`: Optional provider filter

# Returns
- `Vector{Dict}`: Search results with series metadata

# Example
```julia
client = DBnomicsClient()
results = search_series(client, "GDP")
results_fred = search_series(client, "GDP", provider="FRED")
```
"""
function search_series(client::DBnomicsClient, query::String; limit::Int=100, provider::Union{String, Nothing}=nothing)::Vector{Dict}
    # Check cache
    provider_key = provider === nothing ? "all" : provider
    key = cache_key("dbnomics", "search:$query:$provider_key")
    cached = get_cached(client.cache, key)

    if cached !== nothing
        @debug "DBnomics: Search cache hit" query
        return JSON3.read(cached)
    end

    # Rate limit
    if !wait_if_needed(client.rate_limiter)
        throw(ErrorException("Rate limit timeout"))
    end

    # Build request
    params = Dict(
        "q" => query,
        "limit" => string(limit),
        "format" => "json"
    )

    if provider !== nothing
        params["provider_code"] = provider
    end

    url = "$(client.base_url)/series"

    # Execute request
    response = HTTP.get(url, query=params)

    if response.status != 200
        throw(HTTP.Exceptions.StatusError(response.status, response))
    end

    data = JSON3.read(response.body)

    # Extract relevant fields
    results = [
        Dict(
            "code" => series.code,
            "provider" => series.provider_code,
            "dataset" => series.dataset_code,
            "name" => get(series, :name, ""),
            "frequency" => get(series, :frequency, ""),
            "period_start" => get(series, :period_start_day, ""),
            "period_end" => get(series, :period_end_day, ""),
            "last_update" => get(series, :indexed_at, "")
        )
        for series in data.series.docs
    ]

    # Cache results
    set_cached(
        client.cache,
        key,
        JSON3.write(results),
        ttl=3600,  # Cache searches for 1 hour
        metadata=Dict("source" => "dbnomics", "type" => "search")
    )

    return results
end

"""
    get_series_info(client::DBnomicsClient, provider::String, dataset::String, series::String)::Dict

Get metadata for a specific DBnomics series.

# Arguments
- `client::DBnomicsClient`: DBnomics client instance
- `provider::String`: Data provider code
- `dataset::String`: Dataset code
- `series::String`: Series code

# Returns
- `Dict`: Series metadata

# Example
```julia
client = DBnomicsClient()
info = get_series_info(client, "FRED", "series", "GDPC1")
```
"""
function get_series_info(client::DBnomicsClient, provider::String, dataset::String, series::String)::Dict
    # Rate limit
    if !wait_if_needed(client.rate_limiter)
        throw(ErrorException("Rate limit timeout"))
    end

    url = "$(client.base_url)/series/$provider/$dataset/$series"

    params = Dict(
        "observations" => "0",  # Don't fetch observations, just metadata
        "format" => "json"
    )

    response = HTTP.get(url, query=params)

    if response.status != 200
        throw(HTTP.Exceptions.StatusError(response.status, response))
    end

    data = JSON3.read(response.body)
    series_data = data.series

    return Dict(
        "code" => series_data.code,
        "provider" => series_data.provider_code,
        "dataset" => series_data.dataset_code,
        "name" => get(series_data, :name, ""),
        "frequency" => get(series_data, :frequency, ""),
        "period_start" => get(series_data, :period_start_day, ""),
        "period_end" => get(series_data, :period_end_day, ""),
        "last_update" => get(series_data, :indexed_at, ""),
        "dimensions" => get(series_data, :dimensions, Dict()),
        "dataset_name" => get(series_data, :dataset_name, ""),
        "provider_name" => get(series_data, :provider_name, "")
    )
end

"""
    list_providers(client::DBnomicsClient)::Vector{Dict}

List all available data providers in DBnomics.

# Arguments
- `client::DBnomicsClient`: DBnomics client instance

# Returns
- `Vector{Dict}`: List of providers with metadata

# Example
```julia
client = DBnomicsClient()
providers = list_providers(client)
```
"""
function list_providers(client::DBnomicsClient)::Vector{Dict}
    # Check cache
    key = cache_key("dbnomics", "providers")
    cached = get_cached(client.cache, key)

    if cached !== nothing
        @debug "DBnomics: Providers cache hit"
        return JSON3.read(cached)
    end

    # Rate limit
    if !wait_if_needed(client.rate_limiter)
        throw(ErrorException("Rate limit timeout"))
    end

    url = "$(client.base_url)/providers"

    params = Dict("format" => "json")

    response = HTTP.get(url, query=params)

    if response.status != 200
        throw(HTTP.Exceptions.StatusError(response.status, response))
    end

    data = JSON3.read(response.body)

    # Extract provider information
    providers = [
        Dict(
            "code" => provider.code,
            "name" => provider.name,
            "region" => get(provider, :region, ""),
            "website" => get(provider, :website, ""),
            "datasets_count" => get(provider, :nb_datasets, 0)
        )
        for provider in data.providers.docs
    ]

    # Cache providers list (24 hours)
    set_cached(
        client.cache,
        key,
        JSON3.write(providers),
        ttl=86400,
        metadata=Dict("source" => "dbnomics", "type" => "providers")
    )

    return providers
end
