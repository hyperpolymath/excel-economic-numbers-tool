using Test
using Dates

include("../../src/julia/formulas/gdp_growth.jl")

@testset "GDP Growth Tests" begin
    @testset "YoY Growth" begin
        # Quarterly GDP values
        dates = [
            Date(2020, 1, 1),
            Date(2020, 4, 1),
            Date(2020, 7, 1),
            Date(2020, 10, 1),
            Date(2021, 1, 1),
            Date(2021, 4, 1)
        ]
        values = [21000.0, 20000.0, 21500.0, 22000.0, 22500.0, 23000.0]

        growth = gdp_growth(values, dates, method=:yoy)

        # First value should be NaN (no prior year data)
        @test isnan(growth[1])

        # 2021 Q1 vs 2020 Q1: (22500 - 21000) / 21000 * 100 ≈ 7.14%
        @test growth[5] ≈ 7.14 atol=0.1
    end

    @testset "QoQ Growth (Annualized)" begin
        dates = [Date(2021, 1, 1), Date(2021, 4, 1), Date(2021, 7, 1)]
        values = [20000.0, 20500.0, 21000.0]

        growth = gdp_growth(values, dates, method=:qoq)

        # First should be NaN
        @test isnan(growth[1])

        # QoQ annualized: ((20500/20000)^4 - 1) * 100
        expected = ((20500/20000)^4 - 1) * 100
        @test growth[2] ≈ expected atol=0.1
    end

    @testset "CAGR Calculation" begin
        dates = [Date(2015, 1, 1), Date(2020, 1, 1)]
        values = [18000.0, 23000.0]  # 5 years

        cagr = gdp_growth(values, dates, method=:cagr)[1]

        # CAGR = ((23000/18000)^(1/5) - 1) * 100
        expected = ((23000/18000)^(1/5) - 1) * 100
        @test cagr ≈ expected atol=0.1
    end

    @testset "Simple Growth Rate" begin
        values = [100.0, 105.0, 110.0, 108.0]
        growth = simple_growth_rate(values)

        @test isnan(growth[1])
        @test growth[2] ≈ 5.0  # (105-100)/100 * 100
        @test growth[3] ≈ 4.76 atol=0.01  # (110-105)/105 * 100
        @test growth[4] ≈ -1.82 atol=0.01  # (108-110)/110 * 100
    end

    @testset "Real Growth with Deflator" begin
        nominal = [20000.0, 21000.0, 22000.0]
        deflator = [100.0, 105.0, 110.0]  # 5% and 4.76% inflation

        real = real_growth(nominal, deflator)

        # Real GDP = Nominal / (Deflator / 100)
        @test real[1] ≈ 20000.0
        @test real[2] ≈ 20000.0 atol=10  # ~20000 (no real growth)
        @test real[3] ≈ 20000.0 atol=10
    end

    @testset "Contribution to Growth" begin
        consumption = [14000.0, 14500.0, 15000.0]
        gdp = [20000.0, 21000.0, 22000.0]

        contribution = contribution_to_growth(consumption, gdp)

        @test isnan(contribution[1])

        # Q2: (14500 - 14000) / 20000 * 100 = 2.5%
        @test contribution[2] ≈ 2.5

        # Q3: (15000 - 14500) / 21000 * 100 ≈ 2.38%
        @test contribution[3] ≈ 2.38 atol=0.01
    end

    @testset "Edge Cases" begin
        # Single value
        @test_throws ArgumentError gdp_growth([100.0], [Date(2020, 1, 1)])

        # Mismatched lengths
        @test_throws ArgumentError gdp_growth([100.0, 110.0], [Date(2020, 1, 1)])

        # Zero values
        values = [0.0, 100.0]
        dates = [Date(2020, 1, 1), Date(2021, 1, 1)]
        growth = gdp_growth(values, dates, method=:yoy)
        @test isnan(growth[1])
    end
end
