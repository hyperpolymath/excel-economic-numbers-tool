using Test

include("../../src/julia/formulas/elasticity.jl")

@testset "Elasticity Tests" begin
    @testset "Price elasticity - normal demand" begin
        # Typical downward sloping demand
        prices = [10.0, 12.0, 14.0]
        quantities = [100.0, 85.0, 70.0]

        ε = elasticity(quantities, prices, method=:midpoint)

        # Should be negative (inverse relationship)
        @test ε < 0

        # Should be elastic (|ε| > 1)
        @test abs(ε) > 1
    end

    @testset "Income elasticity" begin
        incomes = [30000.0, 40000.0, 50000.0]
        quantities = [10.0, 15.0, 22.0]

        ε_income = income_elasticity(quantities, incomes)

        # Should be positive for normal good
        @test ε_income > 0
    end

    @testset "Cross-price elasticity" begin
        # Substitute goods (coffee and tea)
        coffee_quantities = [100.0, 120.0, 140.0]
        tea_prices = [2.0, 2.5, 3.0]

        ε_cross = cross_price_elasticity(coffee_quantities, tea_prices)

        # Should be positive for substitutes
        @test ε_cross > 0
    end

    @testset "Edge cases" begin
        # Zero price change
        @test_throws ArgumentError elasticity([100.0], [10.0])

        # Different lengths
        @test_throws ArgumentError elasticity([100.0, 90.0], [10.0, 11.0, 12.0])
    end
end
