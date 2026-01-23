using Test
using Dates

include("../../src/julia/utils/rate_limiter.jl")

@testset "RateLimiter Tests" begin
    @testset "Basic functionality" begin
        limiter = RateLimiter(5, window_seconds=60)

        # Should be able to make 5 requests immediately
        for i in 1:5
            @test wait_if_needed(limiter) == true
        end

        # 6th request should be blocked (but we won't wait)
        @test can_proceed(limiter) == false

        # Check current count
        @test get_current_count(limiter) == 5

        # Check remaining
        @test get_remaining(limiter) == 0
    end

    @testset "Reset functionality" begin
        limiter = RateLimiter(3)

        wait_if_needed(limiter)
        wait_if_needed(limiter)
        @test get_current_count(limiter) == 2

        reset(limiter)
        @test get_current_count(limiter) == 0
    end

    @testset "Time window expiration" begin
        limiter = RateLimiter(2, window_seconds=1)

        wait_if_needed(limiter)
        wait_if_needed(limiter)
        @test can_proceed(limiter) == false

        # Wait for window to expire
        sleep(1.1)
        @test can_proceed(limiter) == true
    end
end
