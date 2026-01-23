"""
Advanced Usage Examples - Economic Toolkit v2.0

This file demonstrates advanced features and use cases.
"""

using EconomicToolkit
using Dates
using DataFrames
using Statistics

println("="^60)
println("Economic Toolkit v2.0 - Advanced Usage Examples")
println("="^60)
println()

# ===== Example 1: Multi-Source Data Comparison =====
println("Example 1: Comparing GDP from multiple sources")
println("-"^60)

fred = FREDClient()
wb = WorldBankClient()

start_date = Date(2010, 1, 1)
end_date = Date(2020, 12, 31)

try
    # Fetch US GDP from both sources
    fred_gdp = fetch_series(fred, "GDPC1", start_date, end_date)
    wb_gdp = fetch_series(wb, "NY.GDP.MKTP.CD", "USA", start_date, end_date)

    println("FRED data points: $(nrow(fred_gdp))")
    println("World Bank data points: $(nrow(wb_gdp))")
catch e
    println("Error fetching multi-source data: $e")
end

println()

# ===== Example 2: Advanced Elasticity Analysis =====
println("Example 2: Comparing elasticity calculation methods")
println("-"^60)

# Generate sample data: demand curve
prices = collect(5.0:0.5:15.0)
quantities = @. 200 - 10 * prices + rand(-5:5)  # With noise

ε_midpoint = elasticity(quantities, prices, method=:midpoint)
ε_arc = elasticity(quantities, prices, method=:arc)
ε_point = elasticity(quantities, prices, method=:point)
ε_log = elasticity(quantities, prices, method=:log)

println("Elasticity by method:")
println("  Midpoint: $(round(ε_midpoint, digits=3))")
println("  Arc:      $(round(ε_arc, digits=3))")
println("  Point:    $(round(ε_point, digits=3))")
println("  Log-log:  $(round(ε_log, digits=3))")

println()

# ===== Example 3: Growth Decomposition =====
println("Example 3: GDP growth decomposition")
println("-"^60)

# GDP components over 4 quarters
gdp = [20000.0, 21000.0, 22000.0, 23000.0]
consumption = [14000.0, 14500.0, 15000.0, 15500.0]
investment = [3000.0, 3200.0, 3400.0, 3600.0]
government = [3500.0, 3700.0, 3900.0, 4100.0]

# Calculate contributions
c_contrib = contribution_to_growth(consumption, gdp)
i_contrib = contribution_to_growth(investment, gdp)
g_contrib = contribution_to_growth(government, gdp)

println("GDP growth contributions (percentage points):")
for q in 2:4
    println("Quarter $q:")
    println("  Consumption: $(round(c_contrib[q], digits=2))%")
    println("  Investment:  $(round(i_contrib[q], digits=2))%")
    println("  Government:  $(round(g_contrib[q], digits=2))%")
    total = c_contrib[q] + i_contrib[q] + g_contrib[q]
    println("  Total:       $(round(total, digits=2))%")
    println()
end

println()

# ===== Example 4: Inequality Metrics Comparison =====
println("Example 4: Multiple inequality measures")
println("-"^60)

# Generate sample income distribution
incomes = vcat(
    fill(20000.0, 20),  # Bottom 20%
    fill(35000.0, 30),  # Lower-middle 30%
    fill(55000.0, 30),  # Upper-middle 30%
    fill(100000.0, 15), # High income 15%
    fill(250000.0, 5)   # Top 5%
)

gini = gini_coefficient(incomes)
atkinson1 = atkinson_index(incomes, epsilon=1.0)
atkinson2 = atkinson_index(incomes, epsilon=2.0)
theil = theil_index(incomes)
p90_p10 = percentile_ratio(incomes, 90, 10)
palma = palma_ratio(incomes)

println("Income Distribution Analysis:")
println("  Sample size: $(length(incomes))")
println("  Mean income: \$$(round(mean(incomes), digits=0))")
println("  Median income: \$$(round(median(incomes), digits=0))")
println()
println("Inequality Measures:")
println("  Gini coefficient: $(round(gini, digits=3))")
println("    $(inequality_interpretation(gini))")
println("  Atkinson (ε=1.0): $(round(atkinson1, digits=3))")
println("  Atkinson (ε=2.0): $(round(atkinson2, digits=3))")
println("  Theil index: $(round(theil, digits=3))")
println("  P90/P10 ratio: $(round(p90_p10, digits=2))")
println("  Palma ratio: $(round(palma, digits=2))")

println()

# ===== Example 5: Complex Constraint System =====
println("Example 5: Multi-equation constraint system")
println("-"^60)

# System of equations:
# 1. GDP = C + I + G + NX (identity)
# 2. C = 0.7 * GDP (consumption function)
# 3. I + G = 6000 (fixed investment + government)

system = ConstraintSystem()

# GDP identity
add_constraint(system, "gdp_identity", "GDP = C + I + G + NX",
               ["GDP", "C", "I", "G", "NX"],
               [1.0, -1.0, -1.0, -1.0, -1.0],
               0.0)

# Consumption function: C = 0.7 * GDP → C - 0.7*GDP = 0
add_constraint(system, "consumption", "C = 0.7 * GDP",
               ["C", "GDP"],
               [1.0, -0.7],
               0.0)

# Investment + Government = 6000: I + G = 6000
add_constraint(system, "i_plus_g", "I + G = 6000",
               ["I", "G"],
               [1.0, 1.0],
               6000.0)

# Set known values
set_variable(system, "NX", -500.0, fixed=true)
set_variable(system, "I", 3000.0, fixed=true)

# Solve
success = solve_constraints(system)

if success
    println("Constraint system solved successfully!")
    println()
    println("Solution:")
    println("  GDP = $(round(get_variable(system, "GDP"), digits=1))")
    println("  C = $(round(get_variable(system, "C"), digits=1))")
    println("  I = $(round(get_variable(system, "I"), digits=1))")
    println("  G = $(round(get_variable(system, "G"), digits=1))")
    println("  NX = $(round(get_variable(system, "NX"), digits=1))")
    println()
    println("Verification:")
    println("  C / GDP = $(round(get_variable(system, "C") / get_variable(system, "GDP"), digits=2))")
    println("  I + G = $(round(get_variable(system, "I") + get_variable(system, "G"), digits=1))")
else
    println("Failed to solve constraint system")
end

println()

# ===== Example 6: Cache Management =====
println("Example 6: Advanced cache management")
println("-"^60)

# Get detailed cache stats
stats = get_stats(fred.cache)

println("Cache Statistics:")
for (key, value) in stats
    if key == "by_source"
        println("  Sources:")
        for (source, count) in value
            println("    $source: $count entries")
        end
    else
        println("  $key: $value")
    end
end

# Clear expired entries
cleared = clear_expired(fred.cache)
println()
println("Cleared $cleared expired entries")

# Clear specific source
# cleared_fred = clear_by_source(fred.cache, "fred")
# println("Cleared $cleared_fred FRED entries")

println()

# ===== Example 7: Rate Limiter Behavior =====
println("Example 7: Understanding rate limits")
println("-"^60)

limiter = RateLimiter(5, window_seconds=10)

println("Rate limiter: 5 requests per 10 seconds")
println()

for i in 1:7
    can_proceed = can_proceed(limiter)
    current = get_current_count(limiter)
    remaining = get_remaining(limiter)

    println("Request $i:")
    println("  Can proceed: $can_proceed")
    println("  Current count: $current")
    println("  Remaining: $remaining")

    if can_proceed
        wait_if_needed(limiter)
        println("  ✓ Request allowed")
    else
        println("  ✗ Rate limit exceeded")
    end

    println()
end

println()
println("="^60)
println("Advanced examples complete!")
println("="^60)
