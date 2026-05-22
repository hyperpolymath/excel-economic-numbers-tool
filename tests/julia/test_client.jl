# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2024-2026 Hyperpolymath Contributors

"""
Tests for Economic Toolkit Julia client.

Run with: julia --project=. tests/julia/test_client.jl
"""

using Test

# Add src to load path so EconomicToolkit module is found
push!(LOAD_PATH, joinpath(@__DIR__, "..", "..", "src", "julia"))
using EconomicToolkit

@testset "EconomicToolkit Tests" begin

    @testset "EconomicClient" begin
        @testset "default initialization" begin
            client = EconomicClient()
            @test client.api_url == "http://localhost:8080"
            @test client.api_key === nothing
        end

        @testset "initialization with API key" begin
            client = EconomicClient(api_key="test-key-123")
            @test haskey(client.headers, "Authorization")
            @test client.headers["Authorization"] == "Bearer test-key-123"
        end

        @testset "custom API URL strips trailing slash" begin
            client = EconomicClient(api_url="https://api.example.com/")
            @test client.api_url == "https://api.example.com"
        end
    end

    @testset "DataSources" begin
        @testset "FRED client" begin
            fred = FRED()
            @test source_id(fred) == "fred"
            @test source_name(fred) == "Federal Reserve Economic Data"
        end

        @testset "WorldBank client" begin
            wb = WorldBank()
            @test source_id(wb) == "worldbank"
            @test source_name(wb) == "World Bank"
        end
    end

    @testset "Formulas" begin
        @testset "point elasticity" begin
            quantity = [100.0, 90.0, 80.0, 70.0]
            price = [10.0, 11.0, 12.0, 13.0]
            result = elasticity(quantity, price; method="point")
            @test result isa Float64
            @test result < 0  # Demand curve slopes downward
        end

        @testset "arc elasticity" begin
            quantity = [100.0, 80.0]
            price = [10.0, 12.0]
            result = elasticity(quantity, price; method="arc")
            @test result isa Float64
        end

        @testset "GDP growth period-over-period" begin
            gdp = [100.0, 102.0, 105.0, 108.0]
            growth = gdp_growth(gdp)
            @test length(growth) == 3
            @test all(g -> g > 0, growth)
        end

        @testset "GDP growth annualized" begin
            gdp = [100.0, 110.0]
            growth = gdp_growth(gdp; periods=1)
            @test growth isa Float64
            @test growth > 0
        end

        @testset "Gini coefficient equal distribution" begin
            incomes = [100.0, 100.0, 100.0, 100.0]
            gini = gini_coefficient(incomes)
            @test gini < 0.01  # Near perfect equality
        end

        @testset "Gini coefficient unequal distribution" begin
            incomes = [10.0, 20.0, 50.0, 100.0, 500.0]
            gini = gini_coefficient(incomes)
            @test 0 < gini < 1
        end

        @testset "Lorenz curve" begin
            incomes = [20000.0, 30000.0, 40000.0, 50000.0, 100000.0]
            pop, inc = lorenz_curve(incomes)
            @test pop[1] == 0.0
            @test inc[1] == 0.0
            @test pop[end] == 1.0
            @test inc[end] ≈ 1.0
            @test length(pop) == length(incomes) + 1
        end

        @testset "CAGR" begin
            result = cagr(100.0, 150.0, 5)
            @test result isa Float64
            @test result > 0
        end

        @testset "growth_rate" begin
            result = growth_rate([100.0, 105.0, 110.0])
            @test length(result) == 2
            @test all(r -> r > 0, result)
        end
    end
end
