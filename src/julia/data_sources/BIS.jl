"""
BIS (Bank for International Settlements) Client - STUB

TODO: Implement full client following FRED.jl pattern

API Documentation: https://data.bis.org/
Rate Limit: 60 requests/minute (reasonable)
API Key: Not required
Note: BIS data also available through DBnomics
"""

using HTTP
using JSON3
using Dates

struct BISClient
    base_url::String
    rate_limiter::RateLimiter
    cache::SQLiteCache
    retry_config::RetryConfig

    function BISClient(; cache_ttl::Int=86400)
        base_url = "https://data.bis.org/api"
        rate_limiter = RateLimiter(60)
        cache = SQLiteCache(default_ttl=cache_ttl)
        retry_config = RetryConfig()

        new(base_url, rate_limiter, cache, retry_config)
    end
end

function fetch_series(client::BISClient, series_id::String, start_date::Date, end_date::Date)::DataFrame
    # TODO: Implement BIS API fetch
    # Uses SDMX format
    error("BIS client not yet implemented - STUB")
end

function search_series(client::BISClient, query::String; limit::Int=100)::Vector{Dict}
    # TODO: Implement BIS search
    error("BIS client not yet implemented - STUB")
end
