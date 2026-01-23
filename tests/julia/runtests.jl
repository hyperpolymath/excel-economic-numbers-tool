using Test

println("="^70)
println("Economic Toolkit v2.0 - Test Suite")
println("="^70)
println()

@testset "Economic Toolkit Tests" begin
    println("\n" * "="^70)
    println("Running Utility Tests")
    println("="^70)

    @testset "Utility Tests" begin
        include("test_rate_limiter.jl")
    end

    println("\n" * "="^70)
    println("Running Formula Tests")
    println("="^70)

    @testset "Formula Tests" begin
        include("test_elasticity.jl")
        include("test_gdp_growth.jl")
        include("test_lorenz.jl")
        include("test_constraints.jl")
    end

    # Note: Data source tests require API access and/or mocking
    # Uncomment when you have API keys configured or mocks set up
    #
    # println("\n" * "="^70)
    # println("Running Data Source Tests")
    # println("="^70)
    #
    # @testset "Data Source Tests" begin
    #     include("test_fred.jl")
    #     include("test_worldbank.jl")
    #     include("test_imf.jl")
    #     include("test_oecd.jl")
    #     include("test_dbnomics.jl")
    #     include("test_ecb.jl")
    # end
end

println("\n" * "="^70)
println("Test Suite Complete!")
println("="^70)
