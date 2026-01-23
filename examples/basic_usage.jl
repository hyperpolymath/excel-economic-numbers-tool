"""
Basic Usage Examples - Economic Toolkit v2.0

This file demonstrates basic usage of the Economic Toolkit.
"""

using EconomicToolkit
using Dates
using DataFrames

println("="^60)
println("Economic Toolkit v2.0 - Basic Usage Examples")
println("="^60)
println()

# ===== Example 1: Fetch Data from FRED =====
println("Example 1: Fetching GDP data from FRED")
println("-"^60)

fred = FREDClient()  # Uses env var FRED_API_KEY if available

# Fetch Real GDP (quarterly)
start_date = Date(2020, 1, 1)
end_date = Date(2023, 12, 31)

try
    gdp_data = fetch_series(fred, "GDPC1", start_date, end_date)
    println("Fetched $(nrow(gdp_data)) observations of Real GDP")
    println("First 5 rows:")
    println(first(gdp_data, 5))
catch e
    println("Error fetching FRED data: $e")
    println("(This is expected if no API key is configured)")
end

println()

# ===== Example 2: Search for Series =====
println("Example 2: Searching for inflation-related series")
println("-"^60)

try
    results = search_series(fred, "inflation")
    println("Found $(length(results)) series")
    for (i, result) in enumerate(results[1:min(5, length(results))])
        println("  $(i). $(result["id"]): $(result["title"])")
    end
catch e
    println("Error searching FRED: $e")
end

println()

# ===== Example 3: Calculate Elasticity =====
println("Example 3: Calculating price elasticity of demand")
println("-"^60)

# Example: Coffee prices and quantities
prices = [3.0, 3.5, 4.0, 4.5, 5.0]
quantities = [100.0, 90.0, 82.0, 75.0, 70.0]

ε = elasticity(quantities, prices, method=:midpoint)
println("Prices: $prices")
println("Quantities: $quantities")
println("Price elasticity: $(round(ε, digits=2))")
println("Interpretation: $(elasticity_interpretation(ε))")

println()

# ===== Example 4: Calculate GDP Growth Rates =====
println("Example 4: Calculating GDP growth rates")
println("-"^60)

# Quarterly GDP values
gdp_values = [20000.0, 19500.0, 21000.0, 21500.0, 22000.0, 22500.0]
gdp_dates = [
    Date(2020, 1, 1),
    Date(2020, 4, 1),
    Date(2020, 7, 1),
    Date(2020, 10, 1),
    Date(2021, 1, 1),
    Date(2021, 4, 1)
]

yoy_growth = gdp_growth(gdp_values, gdp_dates, method=:yoy)
qoq_growth = gdp_growth(gdp_values, gdp_dates, method=:qoq)

println("GDP Values: $gdp_values")
println("YoY Growth Rates: $(round.(yoy_growth, digits=2))")
println("QoQ Growth Rates (annualized): $(round.(qoq_growth, digits=2))")

println()

# ===== Example 5: Calculate Gini Coefficient =====
println("Example 5: Measuring income inequality")
println("-"^60)

# Example income distribution
incomes_equal = [50000.0, 50000.0, 50000.0, 50000.0, 50000.0]
incomes_unequal = [10000.0, 20000.0, 30000.0, 60000.0, 180000.0]

gini_equal = gini_coefficient(incomes_equal)
gini_unequal = gini_coefficient(incomes_unequal)

println("Equal distribution: $incomes_equal")
println("  Gini coefficient: $(round(gini_equal, digits=3))")
println("  $(inequality_interpretation(gini_equal))")
println()
println("Unequal distribution: $incomes_unequal")
println("  Gini coefficient: $(round(gini_unequal, digits=3))")
println("  $(inequality_interpretation(gini_unequal))")

println()

# ===== Example 6: GDP Identity Constraint System =====
println("Example 6: Solving GDP identity")
println("-"^60)

# GDP = C + I + G + NX
# Given components, solve for GDP
system = gdp_identity_system(
    C=14000.0,
    I=3000.0,
    G=3500.0,
    NX=-500.0
)

success = solve_constraints(system)

if success
    gdp = get_variable(system, "GDP")
    println("Given:")
    println("  Consumption (C) = 14,000")
    println("  Investment (I) = 3,000")
    println("  Government (G) = 3,500")
    println("  Net Exports (NX) = -500")
    println()
    println("Solved GDP = $(round(gdp, digits=1))")
else
    println("Failed to solve constraint system")
end

println()

# ===== Example 7: Cache Statistics =====
println("Example 7: Cache statistics")
println("-"^60)

stats = get_stats(fred.cache)
println("Cache Statistics:")
println("  Total entries: $(stats["total"])")
println("  Active entries: $(stats["active"])")
println("  Expired entries: $(stats["expired"])")
println("  Database size: $(stats["db_size_mb"]) MB")

println()
println("="^60)
println("Examples complete!")
println("="^60)
