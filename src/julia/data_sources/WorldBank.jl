"""
World Bank Data Source Client

Provides access to World Bank economic indicators covering development data for countries worldwide.

API Documentation: https://datahelpdesk.worldbank.org/knowledgebase/articles/889392-about-the-indicators-api-documentation

Rate Limit: 60 requests/minute
"""

using HTTP
using JSON3
using Dates

"""
    WorldBankClient

Client for fetching data from World Bank API.

# Fields
- `base_url::String`: World Bank API base URL
- `api_key::Union{String, Nothing}`: Optional API key (not required for World Bank)
- `rate_limiter::RateLimiter`: Rate limiter (60/min)
- `cache::SQLiteCache`: Persistent cache
- `retry_config::RetryConfig`: Retry configuration
"""
struct WorldBankClient
    base_url::String
    api_key::Union{String, Nothing}
    rate_limiter::RateLimiter
    cache::SQLiteCache
    retry_config::RetryConfig

    function WorldBankClient(;
        api_key::Union{String, Nothing}=nothing,
        cache_ttl::Int=86400
    )
        base_url = "https://api.worldbank.org/v2"

        # World Bank rate limit: 60 requests per minute
        rate_limiter = RateLimiter(60)

        cache = SQLiteCache(default_ttl=cache_ttl)
        retry_config = RetryConfig()

        new(base_url, api_key, rate_limiter, cache, retry_config)
    end
end

"""
    fetch_series(client::WorldBankClient, series_id::String, country_code::String, start_date::Date, end_date::Date)::DataFrame

Fetch economic time series data from World Bank.

# Arguments
- `client::WorldBankClient`: World Bank client instance
- `series_id::String`: World Bank indicator code (e.g., "NY.GDP.MKTP.CD" for GDP current USD)
- `country_code::String`: ISO 3166-1 alpha-2 or alpha-3 country code (e.g., "US", "USA")
- `start_date::Date`: Start date for data
- `end_date::Date`: End date for data

# Returns
- `DataFrame`: Time series data with columns [:date, :value]

# Example
```julia
client = WorldBankClient()
data = fetch_series(client, "NY.GDP.MKTP.CD", "US", Date(2020, 1, 1), Date(2023, 12, 31))
```
"""
function fetch_series(client::WorldBankClient, series_id::String, country_code::String, start_date::Date, end_date::Date)::DataFrame
    # Check cache first
    key = cache_key("worldbank", series_id, country_code, start_date, end_date)
    cached = get_cached(client.cache, key)

    if cached !== nothing
        @debug "WorldBank: Cache hit" series_id country_code
        return JSON3.read(cached, DataFrame)
    end

    @debug "WorldBank: Cache miss, fetching from API" series_id country_code

    # Rate limit
    if !wait_if_needed(client.rate_limiter)
        @warn "WorldBank: Rate limit wait timeout, attempting cache fallback"
        # Try to return slightly older cached data
        throw(ErrorException("Rate limit timeout"))
    end

    # Build request
    function fetch()
        # World Bank uses year-based date range
        start_year = year(start_date)
        end_year = year(end_date)

        params = Dict(
            "date" => "$(start_year):$(end_year)",
            "format" => "json",
            "per_page" => "1000"  # Get more results per page
        )

        url = "$(client.base_url)/country/$(country_code)/indicator/$(series_id)"

        @debug "WorldBank: Making API request" url series_id country_code

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

        # World Bank API returns array with [metadata, data]
        if length(data) < 2 || data[2] === nothing
            # No data available
            df = DataFrame(date=Date[], value=Union{Float64, Missing}[])
        else
            observations = data[2]

            # Filter out null values and convert to DataFrame
            dates = Date[]
            values = Union{Float64, Missing}[]

            for obs in observations
                if obs.value !== nothing && obs.date !== nothing
                    # World Bank provides year, convert to Date (use Jan 1st)
                    obs_year = parse(Int, obs.date)
                    push!(dates, Date(obs_year, 1, 1))
                    push!(values, Float64(obs.value))
                end
            end

            df = DataFrame(date=dates, value=values)

            # Sort by date (World Bank returns newest first)
            sort!(df, :date)

            # Filter to exact date range
            filter!(row -> start_date <= row.date <= end_date, df)
        end

        # Cache the result
        set_cached(
            client.cache,
            key,
            JSON3.write(df),
            metadata=Dict("source" => "worldbank", "series_id" => series_id, "country" => country_code)
        )

        return df
    else
        # From cache after retry failure
        return body
    end
end

"""
    search_series(client::WorldBankClient, query::String; limit::Int=100)::Vector{Dict}

Search for World Bank indicators by keyword.

# Arguments
- `client::WorldBankClient`: World Bank client instance
- `query::String`: Search query
- `limit::Int`: Maximum results to return (default: 100)

# Returns
- `Vector{Dict}`: Search results with indicator metadata

# Example
```julia
client = WorldBankClient()
results = search_series(client, "GDP")
```
"""
function search_series(client::WorldBankClient, query::String; limit::Int=100)::Vector{Dict}
    # Check cache
    key = cache_key("worldbank", "search:$query")
    cached = get_cached(client.cache, key)

    if cached !== nothing
        @debug "WorldBank: Search cache hit" query
        return JSON3.read(cached)
    end

    # Rate limit
    if !wait_if_needed(client.rate_limiter)
        throw(ErrorException("Rate limit timeout"))
    end

    # Build request
    params = Dict(
        "format" => "json",
        "per_page" => string(limit)
    )

    # World Bank doesn't have direct search, so we fetch all indicators and filter
    # For better performance, we use source=2 (World Development Indicators)
    url = "$(client.base_url)/indicator"

    # Execute request
    response = HTTP.get(url, query=params)

    if response.status != 200
        throw(HTTP.Exceptions.StatusError(response.status, response))
    end

    data = JSON3.read(response.body)

    # World Bank API returns array with [metadata, data]
    if length(data) < 2 || data[2] === nothing
        return Dict[]
    end

    indicators = data[2]

    # Filter by query (case-insensitive)
    query_lower = lowercase(query)
    filtered_results = filter(indicators) do indicator
        name = get(indicator, :name, "")
        id = get(indicator, :id, "")
        source_note = get(indicator, :sourceNote, "")

        lowercase(name) * lowercase(id) * lowercase(source_note) |>
            text -> occursin(query_lower, text)
    end

    # Extract relevant fields
    results = [
        Dict(
            "id" => indicator.id,
            "name" => indicator.name,
            "source" => get(indicator.source, :value, ""),
            "source_note" => get(indicator, :sourceNote, ""),
            "source_organization" => get(indicator, :sourceOrganization, ""),
            "topics" => get(indicator, :topics, [])
        )
        for indicator in first(filtered_results, limit)
    ]

    # Cache results
    set_cached(
        client.cache,
        key,
        JSON3.write(results),
        ttl=3600,  # Cache searches for 1 hour
        metadata=Dict("source" => "worldbank", "type" => "search")
    )

    return results
end

"""
    get_series_info(client::WorldBankClient, series_id::String)::Dict

Get metadata for a specific World Bank indicator.

# Arguments
- `client::WorldBankClient`: World Bank client instance
- `series_id::String`: World Bank indicator code

# Returns
- `Dict`: Indicator metadata

# Example
```julia
client = WorldBankClient()
info = get_series_info(client, "NY.GDP.MKTP.CD")
```
"""
function get_series_info(client::WorldBankClient, series_id::String)::Dict
    # Rate limit
    if !wait_if_needed(client.rate_limiter)
        throw(ErrorException("Rate limit timeout"))
    end

    params = Dict(
        "format" => "json"
    )

    url = "$(client.base_url)/indicator/$(series_id)"
    response = HTTP.get(url, query=params)

    if response.status != 200
        throw(HTTP.Exceptions.StatusError(response.status, response))
    end

    data = JSON3.read(response.body)

    # World Bank API returns array with [metadata, data]
    if length(data) < 2 || data[2] === nothing || isempty(data[2])
        throw(ErrorException("Indicator not found: $series_id"))
    end

    indicator = first(data[2])

    return Dict(
        "id" => indicator.id,
        "name" => indicator.name,
        "source" => get(indicator.source, :value, ""),
        "source_note" => get(indicator, :sourceNote, ""),
        "source_organization" => get(indicator, :sourceOrganization, ""),
        "topics" => get(indicator, :topics, []),
        "unit" => get(indicator, :unit, "")
    )
end
