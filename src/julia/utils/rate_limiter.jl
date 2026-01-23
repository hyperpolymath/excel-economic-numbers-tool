"""
Rate Limiter - Sliding Window Implementation

Prevents exceeding API rate limits by tracking requests in a sliding 60-second window.
"""

using Dates

"""
    RateLimiter

Sliding window rate limiter to prevent exceeding API limits.

# Fields
- `limit::Int`: Maximum requests per window
- `window_seconds::Int`: Window duration in seconds (default: 60)
- `timestamps::Vector{DateTime}`: Request timestamps
- `lock::ReentrantLock`: Thread-safe access
"""
mutable struct RateLimiter
    limit::Int
    window_seconds::Int
    timestamps::Vector{DateTime}
    lock::ReentrantLock

    function RateLimiter(limit::Int; window_seconds::Int=60)
        new(limit, window_seconds, DateTime[], ReentrantLock())
    end
end

"""
    can_proceed(limiter::RateLimiter)::Bool

Check if a request can proceed without exceeding the rate limit.

# Arguments
- `limiter::RateLimiter`: The rate limiter instance

# Returns
- `Bool`: true if request can proceed, false otherwise
"""
function can_proceed(limiter::RateLimiter)::Bool
    lock(limiter.lock) do
        # Remove timestamps outside the window
        cutoff = now() - Second(limiter.window_seconds)
        filter!(t -> t > cutoff, limiter.timestamps)

        # Check if under limit
        return length(limiter.timestamps) < limiter.limit
    end
end

"""
    wait_if_needed(limiter::RateLimiter; max_wait::Int=120)

Wait if necessary to respect rate limits, then record the request.

# Arguments
- `limiter::RateLimiter`: The rate limiter instance
- `max_wait::Int`: Maximum seconds to wait (default: 120)

# Returns
- `Bool`: true if proceeded, false if max wait exceeded
"""
function wait_if_needed(limiter::RateLimiter; max_wait::Int=120)::Bool
    start_time = now()

    while !can_proceed(limiter)
        # Check if we've exceeded max wait time
        if (now() - start_time).value / 1000 > max_wait
            @warn "Rate limiter max wait time exceeded" max_wait
            return false
        end

        # Calculate sleep time
        lock(limiter.lock) do
            if !isempty(limiter.timestamps)
                oldest = minimum(limiter.timestamps)
                wait_until = oldest + Second(limiter.window_seconds)
                sleep_time = max(0.1, (wait_until - now()).value / 1000)
                @debug "Rate limit: sleeping for $(sleep_time)s"
                sleep(sleep_time)
            else
                sleep(0.1)
            end
        end
    end

    # Record this request
    lock(limiter.lock) do
        push!(limiter.timestamps, now())
    end

    return true
end

"""
    record_request(limiter::RateLimiter)

Manually record a request without waiting.

# Arguments
- `limiter::RateLimiter`: The rate limiter instance
"""
function record_request(limiter::RateLimiter)
    lock(limiter.lock) do
        cutoff = now() - Second(limiter.window_seconds)
        filter!(t -> t > cutoff, limiter.timestamps)
        push!(limiter.timestamps, now())
    end
end

"""
    get_current_count(limiter::RateLimiter)::Int

Get the current number of requests in the window.

# Arguments
- `limiter::RateLimiter`: The rate limiter instance

# Returns
- `Int`: Current request count
"""
function get_current_count(limiter::RateLimiter)::Int
    lock(limiter.lock) do
        cutoff = now() - Second(limiter.window_seconds)
        filter!(t -> t > cutoff, limiter.timestamps)
        return length(limiter.timestamps)
    end
end

"""
    reset(limiter::RateLimiter)

Reset the rate limiter, clearing all recorded requests.

# Arguments
- `limiter::RateLimiter`: The rate limiter instance
"""
function reset(limiter::RateLimiter)
    lock(limiter.lock) do
        empty!(limiter.timestamps)
    end
end

"""
    get_remaining(limiter::RateLimiter)::Int

Get the number of requests remaining before hitting the limit.

# Arguments
- `limiter::RateLimiter`: The rate limiter instance

# Returns
- `Int`: Remaining request count
"""
function get_remaining(limiter::RateLimiter)::Int
    count = get_current_count(limiter)
    return max(0, limiter.limit - count)
end
