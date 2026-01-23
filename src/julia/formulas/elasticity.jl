"""
Elasticity Calculations

Provides functions for calculating various types of economic elasticity:
- Price elasticity of demand
- Income elasticity
- Cross-price elasticity
"""

using Statistics
using LinearAlgebra

"""
    elasticity(quantities::Vector{Float64}, prices::Vector{Float64}; method::Symbol=:midpoint)::Float64

Calculate price elasticity of demand using various methods.

# Arguments
- `quantities::Vector{Float64}`: Quantity values
- `prices::Vector{Float64}`: Price values
- `method::Symbol`: Calculation method (:midpoint, :arc, :point, :log)

# Returns
- `Float64`: Elasticity coefficient

# Methods
- `:midpoint` - Midpoint method (default): ε = (ΔQ/Q_avg) / (ΔP/P_avg)
- `:arc` - Arc elasticity
- `:point` - Point elasticity using derivatives
- `:log` - Log-log regression

# Example
```julia
prices = [10.0, 12.0, 14.0]
quantities = [100.0, 90.0, 75.0]
ε = elasticity(quantities, prices)  # Returns negative value (normal demand)
```
"""
function elasticity(quantities::Vector{Float64}, prices::Vector{Float64}; method::Symbol=:midpoint)::Float64
    if length(quantities) != length(prices)
        throw(ArgumentError("Quantities and prices must have same length"))
    end

    if length(quantities) < 2
        throw(ArgumentError("Need at least 2 data points"))
    end

    if method == :midpoint
        return elasticity_midpoint(quantities, prices)
    elseif method == :arc
        return elasticity_arc(quantities, prices)
    elseif method == :point
        return elasticity_point(quantities, prices)
    elseif method == :log
        return elasticity_log(quantities, prices)
    else
        throw(ArgumentError("Unknown method: $method"))
    end
end

"""
    elasticity_midpoint(quantities::Vector{Float64}, prices::Vector{Float64})::Float64

Calculate elasticity using midpoint method.
ε = (ΔQ/Q_avg) / (ΔP/P_avg)
"""
function elasticity_midpoint(quantities::Vector{Float64}, prices::Vector{Float64})::Float64
    # Use first and last points
    q1, q2 = quantities[1], quantities[end]
    p1, p2 = prices[1], prices[end]

    q_avg = (q1 + q2) / 2
    p_avg = (p1 + p2) / 2

    Δq = q2 - q1
    Δp = p2 - p1

    if Δp == 0
        return Inf
    end

    ε = (Δq / q_avg) / (Δp / p_avg)
    return ε
end

"""
    elasticity_arc(quantities::Vector{Float64}, prices::Vector{Float64})::Float64

Calculate arc elasticity (average of elasticities between consecutive points).
"""
function elasticity_arc(quantities::Vector{Float64}, prices::Vector{Float64})::Float64
    n = length(quantities)
    elasticities = Float64[]

    for i in 1:(n-1)
        q1, q2 = quantities[i], quantities[i+1]
        p1, p2 = prices[i], prices[i+1]

        q_avg = (q1 + q2) / 2
        p_avg = (p1 + p2) / 2

        Δq = q2 - q1
        Δp = p2 - p1

        if Δp != 0
            ε = (Δq / q_avg) / (Δp / p_avg)
            push!(elasticities, ε)
        end
    end

    return mean(elasticities)
end

"""
    elasticity_point(quantities::Vector{Float64}, prices::Vector{Float64})::Float64

Calculate point elasticity using numerical derivatives.
ε = (dQ/dP) * (P/Q)
"""
function elasticity_point(quantities::Vector{Float64}, prices::Vector{Float64})::Float64
    # Use linear regression to estimate dQ/dP
    n = length(prices)

    # Simple linear regression: Q = a + b*P
    p_mean = mean(prices)
    q_mean = mean(quantities)

    numerator = sum((prices[i] - p_mean) * (quantities[i] - q_mean) for i in 1:n)
    denominator = sum((prices[i] - p_mean)^2 for i in 1:n)

    if denominator == 0
        return Inf
    end

    b = numerator / denominator  # dQ/dP

    # Calculate elasticity at mean point
    ε = b * (p_mean / q_mean)
    return ε
end

"""
    elasticity_log(quantities::Vector{Float64}, prices::Vector{Float64})::Float64

Calculate elasticity using log-log regression.
log(Q) = a + ε*log(P)
The coefficient ε is the elasticity.
"""
function elasticity_log(quantities::Vector{Float64}, prices::Vector{Float64})::Float64
    # Filter out non-positive values
    valid_indices = findall(i -> quantities[i] > 0 && prices[i] > 0, 1:length(quantities))

    if length(valid_indices) < 2
        throw(ArgumentError("Need at least 2 positive data points for log-log regression"))
    end

    log_q = log.(quantities[valid_indices])
    log_p = log.(prices[valid_indices])

    # Linear regression on logs
    n = length(log_p)
    p_mean = mean(log_p)
    q_mean = mean(log_q)

    numerator = sum((log_p[i] - p_mean) * (log_q[i] - q_mean) for i in 1:n)
    denominator = sum((log_p[i] - p_mean)^2 for i in 1:n)

    if denominator == 0
        return Inf
    end

    ε = numerator / denominator
    return ε
end

"""
    income_elasticity(quantities::Vector{Float64}, incomes::Vector{Float64})::Float64

Calculate income elasticity of demand.
ε_I = (ΔQ/Q) / (ΔI/I)

# Returns
- `Float64`: Income elasticity
  - ε_I > 1: Luxury good
  - 0 < ε_I < 1: Normal good
  - ε_I < 0: Inferior good
"""
function income_elasticity(quantities::Vector{Float64}, incomes::Vector{Float64})::Float64
    return elasticity_midpoint(quantities, incomes)
end

"""
    cross_price_elasticity(quantities_x::Vector{Float64}, prices_y::Vector{Float64})::Float64

Calculate cross-price elasticity of demand.
ε_xy = (ΔQ_x/Q_x) / (ΔP_y/P_y)

# Returns
- `Float64`: Cross-price elasticity
  - ε_xy > 0: Substitute goods
  - ε_xy < 0: Complementary goods
  - ε_xy ≈ 0: Independent goods
"""
function cross_price_elasticity(quantities_x::Vector{Float64}, prices_y::Vector{Float64})::Float64
    return elasticity_midpoint(quantities_x, prices_y)
end

"""
    elasticity_interpretation(ε::Float64)::String

Provide interpretation of elasticity coefficient.
"""
function elasticity_interpretation(ε::Float64)::String
    abs_ε = abs(ε)

    if abs_ε > 1
        return "Elastic ($(abs_ε > 5 ? "highly " : ""))elastic: quantity changes more than proportionally to price)"
    elseif abs_ε < 1 && abs_ε > 0
        return "Inelastic: quantity changes less than proportionally to price"
    elseif abs_ε ≈ 1
        return "Unit elastic: quantity changes proportionally to price"
    elseif abs_ε == 0
        return "Perfectly inelastic: quantity doesn't change with price"
    elseif isinf(abs_ε)
        return "Perfectly elastic: infinite response to price change"
    else
        return "Unknown elasticity"
    end
end
