"""
Retry Logic with Exponential Backoff

Provides robust retry logic for API calls with exponential backoff.
Falls back to cache on final failure.
"""

using HTTP

"""
    RetryConfig

Configuration for retry behavior.

# Fields
- `max_retries::Int`: Maximum number of retry attempts (default: 3)
- `initial_delay::Float64`: Initial delay in seconds (default: 2.0)
- `max_delay::Float64`: Maximum delay in seconds (default: 32.0)
- `backoff_factor::Float64`: Backoff multiplier (default: 2.0)
- `retry_on::Vector{Int}`: HTTP status codes to retry on (default: [429, 500, 502, 503, 504])
"""
struct RetryConfig
    max_retries::Int
    initial_delay::Float64
    max_delay::Float64
    backoff_factor::Float64
    retry_on::Vector{Int}

    function RetryConfig(;
        max_retries::Int=3,
        initial_delay::Float64=2.0,
        max_delay::Float64=32.0,
        backoff_factor::Float64=2.0,
        retry_on::Vector{Int}=[429, 500, 502, 503, 504]
    )
        new(max_retries, initial_delay, max_delay, backoff_factor, retry_on)
    end
end

"""
    should_retry(e::Exception, config::RetryConfig)::Bool

Determine if an exception warrants a retry.

# Arguments
- `e::Exception`: The exception that occurred
- `config::RetryConfig`: Retry configuration

# Returns
- `Bool`: true if should retry, false otherwise
"""
function should_retry(e::Exception, config::RetryConfig)::Bool
    # HTTP status errors
    if e isa HTTP.Exceptions.StatusError
        return e.status in config.retry_on
    end

    # Network errors
    if e isa Base.IOError || e isa Base.EOFError
        return true
    end

    # Timeout errors
    if e isa HTTP.Exceptions.TimeoutError || e isa HTTP.Exceptions.ConnectError
        return true
    end

    return false
end

"""
    calculate_delay(attempt::Int, config::RetryConfig)::Float64

Calculate exponential backoff delay for given attempt.

# Arguments
- `attempt::Int`: Current attempt number (1-indexed)
- `config::RetryConfig`: Retry configuration

# Returns
- `Float64`: Delay in seconds
"""
function calculate_delay(attempt::Int, config::RetryConfig)::Float64
    delay = config.initial_delay * (config.backoff_factor ^ (attempt - 1))
    return min(delay, config.max_delay)
end

"""
    with_retry(f::Function, config::RetryConfig=RetryConfig())

Execute function with retry logic and exponential backoff.

# Arguments
- `f::Function`: Function to execute
- `config::RetryConfig`: Retry configuration

# Returns
- Result of function if successful

# Throws
- Last exception if all retries exhausted
"""
function with_retry(f::Function, config::RetryConfig=RetryConfig())
    last_exception = nothing

    for attempt in 1:(config.max_retries + 1)
        try
            return f()
        catch e
            last_exception = e

            # Don't retry if this is the last attempt
            if attempt > config.max_retries
                @warn "Max retries exhausted" exception=e max_retries=config.max_retries
                rethrow(e)
            end

            # Check if we should retry this exception
            if !should_retry(e, config)
                @warn "Non-retryable exception encountered" exception=e
                rethrow(e)
            end

            # Calculate delay and sleep
            delay = calculate_delay(attempt, config)
            @info "Retrying after error" attempt delay_seconds=delay exception=e
            sleep(delay)
        end
    end

    # Should never reach here, but just in case
    throw(last_exception)
end

"""
    with_retry_and_cache(f::Function, cache::SQLiteCache, cache_key::String, config::RetryConfig=RetryConfig())

Execute function with retry logic, falling back to cache on final failure.

# Arguments
- `f::Function`: Function to execute
- `cache::SQLiteCache`: Cache instance
- `cache_key::String`: Cache key for fallback
- `config::RetryConfig`: Retry configuration

# Returns
- Tuple of (result, from_cache::Bool)
"""
function with_retry_and_cache(f::Function, cache::SQLiteCache, cache_key::String, config::RetryConfig=RetryConfig())
    try
        result = with_retry(f, config)
        return (result, false)
    catch e
        @warn "All retries failed, attempting cache fallback" exception=e

        # Try to get from cache
        cached = get_cached(cache, cache_key)
        if cached !== nothing
            @info "Returning cached data after API failure"
            return (JSON3.read(cached), true)
        else
            @error "No cached data available for fallback"
            rethrow(e)
        end
    end
end
