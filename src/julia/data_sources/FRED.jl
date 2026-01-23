"""
FRED (Federal Reserve Economic Data) Client

Provides access to 800,000+ economic time series from the Federal Reserve Bank of St. Louis.

API Documentation: https://fred.stlouisfed.org/docs/api/

Rate Limit: 120 requests/minute (with API key), 5 requests/minute (without)
"""

using HTTP
using JSON3
using Dates

"""
    FREDClient

Client for fetching data from FRED API.

# Fields
- `base_url::String`: FRED API base URL
- `api_key::Union{String, Nothing}`: Optional API key (increases rate limit)
- `rate_limiter::RateLimiter`: Rate limiter (120/min with key, 5/min without)
- `cache::SQLiteCache`: Persistent cache
- `retry_config::RetryConfig`: Retry configuration
"""
struct FREDClient
    base_url::String
    api_key::Union{String, Nothing}
    rate_limiter::RateLimiter
    cache::SQLiteCache
    retry_config::RetryConfig

    function FREDClient(;
        api_key::Union{String, Nothing}=get(ENV, "FRED_API_KEY", nothing),
        cache_ttl::Int=86400
    )
        base_url = "https://api.stlouisfed.org/fred"

        # Rate limit depends on whether we have an API key
        rate_limit = api_key === nothing ? 5 : 120
        rate_limiter = RateLimiter(rate_limit)

        cache = SQLiteCache(default_ttl=cache_ttl)
        retry_config = RetryConfig()

        new(base_url, api_key, rate_limiter, cache, retry_config)
    end
end

"""
    fetch_series(client::FREDClient, series_id::String, start_date::Date, end_date::Date)::DataFrame

Fetch economic time series data from FRED.

# Arguments
- `client::FREDClient`: FRED client instance
- `series_id::String`: FRED series ID (e.g., "GDPC1" for Real GDP)
- `start_date::Date`: Start date for data
- `end_date::Date`: End date for data

# Returns
- `DataFrame`: Time series data with columns [:date, :value]

# Example
```julia
client = FREDClient()
data = fetch_series(client, "GDPC1", Date(2020, 1, 1), Date(2023, 12, 31))
```
"""
function fetch_series(client::FREDClient, series_id::String, start_date::Date, end_date::Date)::DataFrame
    # Check cache first
    key = cache_key("fred", series_id, start_date, end_date)
    cached = get_cached(client.cache, key)

    if cached !== nothing
        @debug "FRED: Cache hit" series_id
        return JSON3.read(cached, DataFrame)
    end

    @debug "FRED: Cache miss, fetching from API" series_id

    # Rate limit
    if !wait_if_needed(client.rate_limiter)
        @warn "FRED: Rate limit wait timeout, attempting cache fallback"
        # Try to return slightly older cached data
        throw(ErrorException("Rate limit timeout"))
    end

    # Build request
    function fetch()
        params = Dict(
            "series_id" => series_id,
            "observation_start" => Dates.format(start_date, "yyyy-mm-dd"),
            "observation_end" => Dates.format(end_date, "yyyy-mm-dd"),
            "file_type" => "json"
        )

        if client.api_key !== nothing
            params["api_key"] = client.api_key
        end

        url = "$(client.base_url)/series/observations"

        @debug "FRED: Making API request" url series_id

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
        observations = data.observations
        dates = [Date(obs.date) for obs in observations]
        values = [obs.value == "." ? missing : parse(Float64, obs.value) for obs in observations]

        df = DataFrame(date=dates, value=values)

        # Cache the result
        set_cached(
            client.cache,
            key,
            JSON3.write(df),
            metadata=Dict("source" => "fred", "series_id" => series_id)
        )

        return df
    else
        # From cache after retry failure
        return body
    end
end

"""
    search_series(client::FREDClient, query::String; limit::Int=100)::Vector{Dict}

Search for FRED series by keyword.

# Arguments
- `client::FREDClient`: FRED client instance
- `query::String`: Search query
- `limit::Int`: Maximum results to return (default: 100)

# Returns
- `Vector{Dict}`: Search results with series metadata

# Example
```julia
client = FREDClient()
results = search_series(client, "GDP")
```
"""
function search_series(client::FREDClient, query::String; limit::Int=100)::Vector{Dict}
    # Check cache
    key = cache_key("fred", "search:$query")
    cached = get_cached(client.cache, key)

    if cached !== nothing
        @debug "FRED: Search cache hit" query
        return JSON3.read(cached)
    end

    # Rate limit
    if !wait_if_needed(client.rate_limiter)
        throw(ErrorException("Rate limit timeout"))
    end

    # Build request
    params = Dict(
        "search_text" => query,
        "limit" => string(limit),
        "file_type" => "json"
    )

    if client.api_key !== nothing
        params["api_key"] = client.api_key
    end

    url = "$(client.base_url)/series/search"

    # Execute request
    response = HTTP.get(url, query=params)

    if response.status != 200
        throw(HTTP.Exceptions.StatusError(response.status, response))
    end

    data = JSON3.read(response.body)

    # Extract relevant fields
    results = [
        Dict(
            "id" => series.id,
            "title" => series.title,
            "frequency" => get(series, :frequency, ""),
            "units" => get(series, :units, ""),
            "seasonal_adjustment" => get(series, :seasonal_adjustment, ""),
            "last_updated" => get(series, :last_updated, "")
        )
        for series in data.seriess
    ]

    # Cache results
    set_cached(
        client.cache,
        key,
        JSON3.write(results),
        ttl=3600,  # Cache searches for 1 hour
        metadata=Dict("source" => "fred", "type" => "search")
    )

    return results
end

"""
    get_series_info(client::FREDClient, series_id::String)::Dict

Get metadata for a specific FRED series.

# Arguments
- `client::FREDClient`: FRED client instance
- `series_id::String`: FRED series ID

# Returns
- `Dict`: Series metadata

# Example
```julia
client = FREDClient()
info = get_series_info(client, "GDPC1")
```
"""
function get_series_info(client::FREDClient, series_id::String)::Dict
    # Rate limit
    if !wait_if_needed(client.rate_limiter)
        throw(ErrorException("Rate limit timeout"))
    end

    params = Dict(
        "series_id" => series_id,
        "file_type" => "json"
    )

    if client.api_key !== nothing
        params["api_key"] = client.api_key
    end

    url = "$(client.base_url)/series"
    response = HTTP.get(url, query=params)

    data = JSON3.read(response.body)
    series = first(data.seriess)

    return Dict(
        "id" => series.id,
        "title" => series.title,
        "observation_start" => series.observation_start,
        "observation_end" => series.observation_end,
        "frequency" => series.frequency,
        "units" => series.units,
        "seasonal_adjustment" => get(series, :seasonal_adjustment, ""),
        "notes" => get(series, :notes, "")
    )
end
