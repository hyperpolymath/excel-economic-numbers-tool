"""
Eurostat Client - STUB

TODO: Implement full client following FRED.jl pattern

API Documentation: https://ec.europa.eu/eurostat/web/json-and-unicode-web-services
Rate Limit: 60 requests/minute (reasonable)
API Key: Not required
"""

using HTTP
using JSON3
using Dates

struct EurostatClient
    base_url::String
    rate_limiter::RateLimiter
    cache::SQLiteCache
    retry_config::RetryConfig

    function EurostatClient(; cache_ttl::Int=86400)
        base_url = "https://ec.europa.eu/eurostat/api/dissemination"
        rate_limiter = RateLimiter(60)
        cache = SQLiteCache(default_ttl=cache_ttl)
        retry_config = RetryConfig()

        new(base_url, rate_limiter, cache, retry_config)
    end
end

function fetch_series(client::EurostatClient, series_id::String, start_date::Date, end_date::Date)::DataFrame
    # TODO: Implement Eurostat API fetch
    # Uses JSON-stat or SDMX format
    error("Eurostat client not yet implemented - STUB")
end

function search_series(client::EurostatClient, query::String; limit::Int=100)::Vector{Dict}
    # TODO: Implement Eurostat search
    error("Eurostat client not yet implemented - STUB")
end
