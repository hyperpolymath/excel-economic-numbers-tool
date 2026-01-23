using Test

include("../../src/julia/formulas/constraints.jl")

@testset "Constraint System Tests" begin
    @testset "Basic Constraint System" begin
        system = ConstraintSystem()

        @test length(system.constraints) == 0
        @test length(system.variables) == 0
        @test length(system.fixed) == 0
    end

    @testset "GDP Identity System" begin
        # GDP = C + I + G + NX
        # Given C, I, G, NX, solve for GDP
        system = gdp_identity_system(
            C=14000.0,
            I=3000.0,
            G=3500.0,
            NX=-500.0
        )

        # Solve
        success = solve_constraints(system)
        @test success == true

        # Check GDP
        gdp = get_variable(system, "GDP")
        @test gdp ≈ 20000.0 atol=0.1
    end

    @testset "GDP Identity - Solve for Component" begin
        # Given GDP and 3 components, solve for 4th
        system = gdp_identity_system(
            GDP=20000.0,
            C=14000.0,
            I=3000.0,
            G=3500.0
        )

        success = solve_constraints(system)
        @test success == true

        nx = get_variable(system, "NX")
        @test nx ≈ -500.0 atol=0.1
    end

    @testset "Adding Custom Constraint" begin
        system = ConstraintSystem()

        # Simple equation: X + Y = 10
        add_constraint(
            system,
            "sum_to_10",
            "X + Y = 10",
            ["X", "Y"],
            [1.0, 1.0],
            10.0
        )

        # Set X = 6, solve for Y
        set_variable(system, "X", 6.0, fixed=true)

        success = solve_constraints(system)
        @test success == true

        y = get_variable(system, "Y")
        @test y ≈ 4.0 atol=0.1
    end

    @testset "Multiple Constraints" begin
        system = ConstraintSystem()

        # X + Y = 10
        add_constraint(system, "c1", "X + Y = 10", ["X", "Y"], [1.0, 1.0], 10.0)

        # X - Y = 2
        add_constraint(system, "c2", "X - Y = 2", ["X", "Y"], [1.0, -1.0], 2.0)

        success = solve_constraints(system)
        @test success == true

        # Solution: X = 6, Y = 4
        x = get_variable(system, "X")
        y = get_variable(system, "Y")

        @test x ≈ 6.0 atol=0.2
        @test y ≈ 4.0 atol=0.2
    end

    @testset "Check Constraints" begin
        system = ConstraintSystem()

        add_constraint(system, "c1", "X + Y = 100", ["X", "Y"], [1.0, 1.0], 100.0)

        # Set values that satisfy constraint
        set_variable(system, "X", 40.0)
        set_variable(system, "Y", 60.0)

        @test check_constraints(system) == true

        # Set values that don't satisfy
        set_variable(system, "X", 50.0)
        set_variable(system, "Y", 50.0)

        # Should still be satisfied
        @test check_constraints(system) == true

        # Set values that violate constraint
        set_variable(system, "X", 100.0)
        set_variable(system, "Y", 100.0)

        @test check_constraints(system) == false
    end

    @testset "Economic Identity - Income Approach" begin
        # GDP = Wages + Profits + Rent + Interest
        system = ConstraintSystem()

        add_constraint(
            system,
            "gdp_income",
            "GDP = W + P + R + I",
            ["GDP", "W", "P", "R", "I"],
            [1.0, -1.0, -1.0, -1.0, -1.0],
            0.0
        )

        # Set income components
        set_variable(system, "W", 12000.0, fixed=true)  # Wages
        set_variable(system, "P", 5000.0, fixed=true)   # Profits
        set_variable(system, "R", 2000.0, fixed=true)   # Rent
        set_variable(system, "I", 1000.0, fixed=true)   # Interest

        success = solve_constraints(system)
        @test success == true

        gdp = get_variable(system, "GDP")
        @test gdp ≈ 20000.0 atol=0.1
    end

    @testset "Budget Constraint" begin
        # Income = Consumption + Savings
        system = ConstraintSystem()

        add_constraint(
            system,
            "budget",
            "Y = C + S",
            ["Y", "C", "S"],
            [1.0, -1.0, -1.0],
            0.0
        )

        # Income = 50k, Consumption = 40k, solve for Savings
        set_variable(system, "Y", 50000.0, fixed=true)
        set_variable(system, "C", 40000.0, fixed=true)

        success = solve_constraints(system)
        @test success == true

        savings = get_variable(system, "S")
        @test savings ≈ 10000.0 atol=0.1
    end

    @testset "Variable Management" begin
        system = ConstraintSystem()

        # Set variable
        set_variable(system, "X", 10.0)
        @test get_variable(system, "X") == 10.0

        # Set fixed variable
        set_variable(system, "Y", 20.0, fixed=true)
        @test "Y" in system.fixed

        # Get non-existent variable
        @test get_variable(system, "Z") === nothing
    end
end
