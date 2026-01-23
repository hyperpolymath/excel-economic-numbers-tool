# SPDX-License-Identifier: PMPL-1.0-or-later
"""
Rate limiting middleware for Economic Toolkit REST API.

Implements token bucket algorithm for API rate limiting.
"""

using HTTP
using JSON3
using Dates

"""
Token bucket rate limiter.
"""
mutable struct TokenBucket
    capacity::Int
    tokens::Float64
    fill_rate::Float64
    last_update::DateTime

    function TokenBucket(capacity::Int, fill_rate::Float64)
        new(capacity, Float64(capacity), fill_rate, now())
    end
end

"""
Try to consume tokens from the bucket.
"""
function try_consume!(bucket::TokenBucket, tokens::Int=1)::Bool
    current_time = now()
    time_passed = (current_time - bucket.last_update).value / 1000.0  # seconds

    # Refill tokens based on time passed
    bucket.tokens = min(
        bucket.capacity,
        bucket.tokens + time_passed * bucket.fill_rate
    )
    bucket.last_update = current_time

    # Try to consume tokens
    if bucket.tokens >= tokens
        bucket.tokens -= tokens
        return true
    end

    return false
end

"""
Rate limiter middleware.
"""
struct RateLimiter
    buckets::Dict{String, TokenBucket}
    requests_per_minute::Int
    enabled::Bool

    function RateLimiter(requests_per_minute::Int=60; enabled::Bool=true)
        new(Dict{String, TokenBucket}(), requests_per_minute, enabled)
    end
end

"""
Get or create bucket for client identifier.
"""
function get_bucket!(limiter::RateLimiter, client_id::String)::TokenBucket
    if !haskey(limiter.buckets, client_id)
        limiter.buckets[client_id] = TokenBucket(
            limiter.requests_per_minute,
            limiter.requests_per_minute / 60.0  # tokens per second
        )
    end
    return limiter.buckets[client_id]
end

"""
Middleware function for rate limiting.
"""
function rate_limit(limiter::RateLimiter)
    return function(handler)
        return function(req::HTTP.Request)
            if !limiter.enabled
                return handler(req)
            end

            # Extract client identifier (IP address or API key)
            client_id = get(req.headers, "X-Forwarded-For", req.context[:remote_address])

            bucket = get_bucket!(limiter, client_id)

            if !try_consume!(bucket)
                return HTTP.Response(429, JSON3.write(Dict(
                    "error" => "Too Many Requests",
                    "message" => "Rate limit exceeded. Try again later.",
                    "retry_after" => 60
                )))
            end

            return handler(req)
        end
    end
end
