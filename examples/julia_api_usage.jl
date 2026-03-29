#!/usr/bin/env julia
# SPDX-License-Identifier: PMPL-1.0-or-later
# SPDX-FileCopyrightText: 2024-2026 Hyperpolymath Contributors

"""
Example usage of Economic Toolkit Julia API.

This script demonstrates how to use the Julia module to access
economic data and perform analysis.
"""

# Add source path for local development
push!(LOAD_PATH, joinpath(@__DIR__, "..", "src", "julia"))
using EconomicToolkit
using Dates

"""
    example_basic_client()

Basic client usage example.
"""
function example_basic_client()
    println("=== Basic Client Usage ===\n")

    # Initialize client (connects to REST API backend)
    client = EconomicClient(api_url="http://localhost:8080")

    # Check health
    health_status = health(client)
    println("API Status: $health_status")

    # List available data sources
    sources = list_sources(client)
    println("\nAvailable sources: $(length(sources))")
    for source in sources
        println("  - $(source["name"]) ($(source["id"])): $(source["status"])")
    end
end

"""
    example_fred_data()

FRED data access example.
"""
function example_fred_data()
    println("\n=== FRED Data Access ===\n")

    # Create FRED client
    fred = FRED()

    # Search for unemployment rate series
    results = datasource_search(fred, "unemployment rate")
    println("Found $(length(results)) series matching 'unemployment rate'")

    # Fetch US unemployment rate
    data = datasource_fetch(
        fred,
        "UNRATE";
        start_date=Date(2020, 1, 1),
        end_date=Date(2023, 12, 31),
    )
    println("\nUS Unemployment Rate (2020-2023):")
    println("  Series: $(get(data, "series_id", "N/A"))")
    println("  Points: $(length(get(data, "observations", [])))")
end

"""
    example_worldbank_data()

World Bank data access example.
"""
function example_worldbank_data()
    println("\n=== World Bank Data ===\n")

    wb = WorldBank()

    # Fetch US GDP
    data = datasource_fetch(
        wb,
        "USA";
        start_date=Date(2015, 1, 1),
        end_date=Date(2023, 12, 31),
    )
    println("US GDP data: $data")
end

"""
    example_formulas()

Economic formulas example.
"""
function example_formulas()
    println("\n=== Economic Formulas ===\n")

    # GDP growth calculation
    gdp_values = [100.0, 102.0, 105.0, 108.0, 110.0]
    growth_rates = gdp_growth(gdp_values)
    println("GDP Growth Rates: $growth_rates")

    # CAGR calculation
    cagr_value = cagr(100.0, 150.0, 5)
    println("CAGR over 5 years: $(round(cagr_value; digits=2))%")

    # Elasticity calculation
    quantity = [100.0, 90.0, 80.0, 70.0, 60.0]
    price = [10.0, 11.0, 12.0, 13.0, 14.0]
    elast = elasticity(quantity, price; method="point")
    println("Price Elasticity of Demand: $(round(elast; digits=2))")

    # Gini coefficient (income inequality)
    incomes = [20000.0, 30000.0, 40000.0, 50000.0, 100000.0, 500000.0]
    gini = gini_coefficient(incomes)
    println("Gini Coefficient: $(round(gini; digits=3))")

    # Lorenz curve
    population, income_share = lorenz_curve(incomes)
    println("Lorenz Curve: $(length(population)) points")
end

"""
    example_combined_analysis()

Combined analysis example.
"""
function example_combined_analysis()
    println("\n=== Combined Analysis ===\n")

    # In real usage, would fetch actual data from World Bank
    # For demo, using sample data
    println("Fetching GDP data from World Bank...")
    gdp_data = [100.0, 103.0, 107.0, 110.0, 115.0]

    # Calculate various metrics
    growth = gdp_growth(gdp_data)
    compound_growth = cagr(gdp_data[1], gdp_data[end], length(gdp_data) - 1)

    println("Period-over-period growth rates: $growth")
    println("Compound annual growth rate: $(round(compound_growth; digits=2))%")
end

"""
    main()

Run all examples.
"""
function main()
    println("Economic Toolkit Julia API Examples")
    println("=" ^ 60)

    try
        example_basic_client()
    catch e
        println("Error: $e (Server may not be running)")
    end

    example_formulas()
    example_combined_analysis()

    println("\n" * "=" ^ 60)
    println("Examples completed!")
end

# Run if executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
