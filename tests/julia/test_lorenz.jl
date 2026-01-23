using Test

include("../../src/julia/formulas/lorenz.jl")

@testset "Lorenz and Inequality Tests" begin
    @testset "Gini Coefficient - Perfect Equality" begin
        # Everyone has the same income
        incomes = [50000.0, 50000.0, 50000.0, 50000.0, 50000.0]
        gini = gini_coefficient(incomes)

        @test gini ≈ 0.0 atol=0.01
    end

    @testset "Gini Coefficient - High Inequality" begin
        # Very unequal distribution
        incomes = [10000.0, 10000.0, 10000.0, 10000.0, 100000.0]
        gini = gini_coefficient(incomes)

        # Should indicate high inequality
        @test gini > 0.4
        @test gini < 1.0
    end

    @testset "Lorenz Curve" begin
        incomes = [10000.0, 20000.0, 30000.0, 40000.0, 50000.0]
        pop_share, income_share = lorenz_curve(incomes)

        # Check structure
        @test length(pop_share) == length(incomes) + 1
        @test length(income_share) == length(incomes) + 1

        # First point should be (0, 0)
        @test pop_share[1] == 0.0
        @test income_share[1] == 0.0

        # Last point should be (1, 1)
        @test pop_share[end] == 1.0
        @test income_share[end] ≈ 1.0 atol=0.01

        # Income share should be monotonically increasing
        for i in 2:length(income_share)
            @test income_share[i] >= income_share[i-1]
        end
    end

    @testset "Gini from Lorenz" begin
        incomes = [20000.0, 30000.0, 40000.0, 60000.0]

        # Calculate Gini directly
        gini_direct = gini_coefficient(incomes)

        # Calculate Gini from Lorenz curve
        pop_share, income_share = lorenz_curve(incomes)
        gini_lorenz = gini_from_lorenz(pop_share, income_share)

        # Should be approximately equal
        @test gini_direct ≈ gini_lorenz atol=0.05
    end

    @testset "Atkinson Index" begin
        incomes = [10000.0, 20000.0, 30000.0, 40000.0, 50000.0]

        # Different epsilon values
        a1 = atkinson_index(incomes, epsilon=1.0)
        a2 = atkinson_index(incomes, epsilon=0.5)
        a3 = atkinson_index(incomes, epsilon=2.0)

        # All should be between 0 and 1
        @test 0.0 <= a1 <= 1.0
        @test 0.0 <= a2 <= 1.0
        @test 0.0 <= a3 <= 1.0

        # Higher epsilon = more aversion to inequality = higher index
        @test a3 > a1 > a2
    end

    @testset "Theil Index" begin
        # Equal distribution
        equal_incomes = [30000.0, 30000.0, 30000.0]
        theil_equal = theil_index(equal_incomes)
        @test theil_equal ≈ 0.0 atol=0.01

        # Unequal distribution
        unequal_incomes = [10000.0, 30000.0, 60000.0]
        theil_unequal = theil_index(unequal_incomes)
        @test theil_unequal > 0.0
    end

    @testset "Percentile Ratio" begin
        # Create distribution with known percentiles
        incomes = collect(1000.0:1000.0:100000.0)  # 100 people, 1k to 100k

        # P90/P10 ratio
        ratio = percentile_ratio(incomes, 90, 10)

        # P90 ≈ 90k, P10 ≈ 10k, ratio ≈ 9
        @test ratio ≈ 9.0 atol=0.5
    end

    @testset "Palma Ratio" begin
        # Simple distribution
        incomes = vcat(
            fill(10000.0, 40),  # Bottom 40%: 10k each
            fill(50000.0, 50),  # Middle 50%: 50k each
            fill(200000.0, 10)  # Top 10%: 200k each
        )

        palma = palma_ratio(incomes)

        # Top 10% income: 10 * 200k = 2M
        # Bottom 40% income: 40 * 10k = 400k
        # Ratio should be 5
        @test palma ≈ 5.0 atol=0.5
    end

    @testset "Inequality Interpretation" begin
        # Low inequality
        @test occursin("Low", inequality_interpretation(0.25))

        # Moderate inequality
        @test occursin("Moderate", inequality_interpretation(0.35))

        # High inequality
        @test occursin("High", inequality_interpretation(0.45))

        # Very high inequality
        @test occursin("Very high", inequality_interpretation(0.55))

        # Extreme inequality
        @test occursin("Extreme", inequality_interpretation(0.65))
    end

    @testset "Edge Cases" begin
        # Negative incomes
        @test_throws ArgumentError gini_coefficient([-10000.0, 20000.0])

        # Zero total income
        zero_incomes = [0.0, 0.0, 0.0]
        @test gini_coefficient(zero_incomes) == 0.0

        # Single person
        single = [50000.0]
        @test gini_coefficient(single) == 0.0
    end

    @testset "Real-World Examples" begin
        # USA (high inequality): Gini ≈ 0.41
        usa_like = [10000.0, 25000.0, 40000.0, 60000.0, 150000.0]
        gini_usa = gini_coefficient(usa_like)
        @test 0.35 < gini_usa < 0.50

        # Nordic country (low inequality): Gini ≈ 0.27
        nordic_like = [30000.0, 35000.0, 40000.0, 45000.0, 55000.0]
        gini_nordic = gini_coefficient(nordic_like)
        @test 0.10 < gini_nordic < 0.35
    end
end
