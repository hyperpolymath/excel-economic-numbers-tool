# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2024-2026 Hyperpolymath Contributors

"""
    elasticity(quantity, price; method="point")

Calculate price elasticity of demand.

# Arguments
- `quantity::Vector{<:Real}`: Quantity values
- `price::Vector{<:Real}`: Price values
- `method::String`: "point" or "arc" elasticity (default: "point")

# Returns
Elasticity coefficient as `Float64`.

# Examples
```julia
elasticity([100, 90, 80, 70], [10, 11, 12, 13])           # point elasticity
elasticity([100, 80], [10, 12]; method="arc")               # arc elasticity
```
"""
function elasticity(
    quantity::Vector{<:Real},
    price::Vector{<:Real};
    method::String = "point",
)::Float64
    q = Float64.(quantity)
    p = Float64.(price)

    if method == "point"
        # Point elasticity: (dQ/dP) * (P/Q)
        dq = diff(q)
        dp = diff(p)
        elasticities = (dq ./ dp) .* (p[1:end-1] ./ q[1:end-1])
        return mean(elasticities)

    elseif method == "arc"
        # Arc elasticity: ((Q2-Q1)/(Q2+Q1)) / ((P2-P1)/(P2+P1))
        q1, q2 = q[1], q[end]
        p1, p2 = p[1], p[end]
        return ((q2 - q1) / (q2 + q1)) / ((p2 - p1) / (p2 + p1))

    else
        throw(ArgumentError("Unknown method: $method"))
    end
end

# Internal mean function to avoid depending on Statistics.jl for one function
function mean(x::AbstractVector)
    return sum(x) / length(x)
end

"""
    gdp_growth(gdp_values; periods=nothing)

Calculate GDP growth rate(s).

# Arguments
- `gdp_values::Vector{<:Real}`: GDP values over time
- `periods::Union{Int, Nothing}`: Number of periods for annualization
  (default: nothing, returns period-over-period)

# Returns
Growth rate(s) as percentage. Returns a `Float64` for annualized or single-period,
or a `Vector{Float64}` for multi-period results.

# Examples
```julia
gdp_growth([100, 102, 105, 108])        # period-over-period rates
gdp_growth([100, 110]; periods=1)        # annualized rate
```
"""
function gdp_growth(
    gdp_values::Vector{<:Real};
    periods::Union{Int, Nothing} = nothing,
)
    vals = Float64.(gdp_values)

    # Period-over-period growth
    growth_rates = diff(vals) ./ vals[1:end-1] .* 100.0

    if periods === nothing
        return length(growth_rates) > 1 ? growth_rates : growth_rates[1]
    end

    # Annualized growth rate
    total_growth = (vals[end] / vals[1])^(1.0 / periods) - 1.0
    return total_growth * 100.0
end

"""
    gini_coefficient(incomes)

Calculate Gini coefficient for income distribution.

# Arguments
- `incomes::Vector{<:Real}`: Income values

# Returns
Gini coefficient as `Float64` (0 = perfect equality, 1 = perfect inequality).

# Examples
```julia
gini_coefficient([100, 100, 100, 100])    # near 0 (equality)
gini_coefficient([10, 20, 50, 100, 500])  # between 0 and 1
```
"""
function gini_coefficient(incomes::Vector{<:Real})::Float64
    sorted_incomes = sort(Float64.(incomes))
    n = length(sorted_incomes)

    cumulative_sum = cumsum(sorted_incomes)
    indices = collect(0:n-1)
    weighted_sum = sum((n .- indices) .* sorted_incomes)

    return (2.0 * weighted_sum) / (n * cumulative_sum[end]) - (n + 1.0) / n
end

"""
    lorenz_curve(incomes)

Calculate Lorenz curve coordinates.

# Arguments
- `incomes::Vector{<:Real}`: Income values

# Returns
A tuple `(cumulative_population_share, cumulative_income_share)` where each
element is a `Vector{Float64}` starting from the origin (0, 0).

# Examples
```julia
pop, income = lorenz_curve([20000, 30000, 40000, 50000, 100000])
```
"""
function lorenz_curve(incomes::Vector{<:Real})::Tuple{Vector{Float64}, Vector{Float64}}
    sorted_incomes = sort(Float64.(incomes))
    n = length(sorted_incomes)

    cumulative_income = cumsum(sorted_incomes) ./ sum(sorted_incomes)
    cumulative_population = collect(1:n) ./ n

    # Add origin point
    cumulative_population = vcat([0.0], cumulative_population)
    cumulative_income = vcat([0.0], cumulative_income)

    return (cumulative_population, cumulative_income)
end

"""
    cagr(beginning_value, ending_value, num_periods)

Calculate Compound Annual Growth Rate (CAGR).

# Arguments
- `beginning_value::Real`: Starting value
- `ending_value::Real`: Ending value
- `num_periods::Int`: Number of periods

# Returns
CAGR as percentage (`Float64`).

# Examples
```julia
cagr(100, 150, 5)  # CAGR over 5 years
```
"""
function cagr(beginning_value::Real, ending_value::Real, num_periods::Int)::Float64
    return ((ending_value / beginning_value)^(1.0 / num_periods) - 1.0) * 100.0
end

"""
    growth_rate(values)

Calculate period-over-period growth rates.

# Arguments
- `values::Vector{<:Real}`: Time series values

# Returns
Growth rates as percentages. Returns a `Float64` for a single rate,
or a `Vector{Float64}` for multiple rates.

# Examples
```julia
growth_rate([100, 105, 110])  # two growth rates
```
"""
function growth_rate(values::Vector{<:Real})
    vals = Float64.(values)
    rates = diff(vals) ./ vals[1:end-1] .* 100.0
    return length(rates) > 1 ? rates : rates[1]
end
