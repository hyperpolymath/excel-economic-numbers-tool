"""
Lorenz Curve and Gini Coefficient

Tools for measuring income/wealth inequality:
- Lorenz curve calculation
- Gini coefficient
- Other inequality measures
"""

using Statistics

"""
    lorenz_curve(incomes::Vector{Float64})::Tuple{Vector{Float64}, Vector{Float64}}

Calculate Lorenz curve coordinates.

The Lorenz curve plots cumulative share of income against cumulative share of population.

# Arguments
- `incomes::Vector{Float64}`: Income distribution (one value per person/household)

# Returns
- `Tuple{Vector{Float64}, Vector{Float64}}`: (cumulative_population_share, cumulative_income_share)

# Example
```julia
incomes = [10000.0, 20000.0, 30000.0, 50000.0, 100000.0]
pop_share, income_share = lorenz_curve(incomes)
```
"""
function lorenz_curve(incomes::Vector{Float64})::Tuple{Vector{Float64}, Vector{Float64}}
    if any(incomes .< 0)
        throw(ArgumentError("Incomes cannot be negative"))
    end

    n = length(incomes)

    # Sort incomes in ascending order
    sorted_incomes = sort(incomes)

    # Calculate cumulative sums
    cumulative_income = cumsum(sorted_incomes)
    total_income = sum(sorted_incomes)

    # Calculate shares
    population_share = collect(0:n) ./ n

    if total_income == 0
        income_share = zeros(n + 1)
    else
        income_share = vcat([0.0], cumulative_income ./ total_income)
    end

    return (population_share, income_share)
end

"""
    gini_coefficient(incomes::Vector{Float64})::Float64

Calculate Gini coefficient of inequality.

Gini coefficient ranges from 0 (perfect equality) to 1 (perfect inequality).

# Arguments
- `incomes::Vector{Float64}`: Income distribution

# Returns
- `Float64`: Gini coefficient

# Interpretation
- 0.0-0.3: Low inequality
- 0.3-0.4: Moderate inequality
- 0.4-0.5: High inequality
- 0.5+: Very high inequality

# Example
```julia
incomes = [10000.0, 20000.0, 30000.0, 50000.0, 100000.0]
gini = gini_coefficient(incomes)
# Returns approximately 0.36
```
"""
function gini_coefficient(incomes::Vector{Float64})::Float64
    if any(incomes .< 0)
        throw(ArgumentError("Incomes cannot be negative"))
    end

    n = length(incomes)

    if n == 0
        return NaN
    end

    # Sort incomes
    sorted_incomes = sort(incomes)

    # Calculate Gini using formula:
    # G = (2 * Σ(i * y_i)) / (n * Σ(y_i)) - (n + 1) / n

    total_income = sum(sorted_incomes)

    if total_income == 0
        return 0.0
    end

    weighted_sum = sum(i * sorted_incomes[i] for i in 1:n)

    gini = (2 * weighted_sum) / (n * total_income) - (n + 1) / n

    return gini
end

"""
    gini_from_lorenz(population_share::Vector{Float64}, income_share::Vector{Float64})::Float64

Calculate Gini coefficient from Lorenz curve coordinates.

Uses trapezoidal rule to integrate area between Lorenz curve and line of equality.

# Arguments
- `population_share::Vector{Float64}`: Cumulative population share
- `income_share::Vector{Float64}`: Cumulative income share

# Returns
- `Float64`: Gini coefficient
"""
function gini_from_lorenz(population_share::Vector{Float64}, income_share::Vector{Float64})::Float64
    if length(population_share) != length(income_share)
        throw(ArgumentError("Population and income shares must have same length"))
    end

    n = length(population_share)

    # Area under Lorenz curve using trapezoidal rule
    area_under_lorenz = 0.0
    for i in 2:n
        dx = population_share[i] - population_share[i-1]
        avg_height = (income_share[i] + income_share[i-1]) / 2
        area_under_lorenz += dx * avg_height
    end

    # Area under line of equality is 0.5 (triangle)
    area_under_equality = 0.5

    # Gini = A / (A + B) where A is area between curves
    # Simplified: Gini = 2 * A = 1 - 2*B where B is area under Lorenz
    gini = 1 - 2 * area_under_lorenz

    return max(0.0, min(1.0, gini))  # Clamp to [0, 1]
end

"""
    atkinson_index(incomes::Vector{Float64}; epsilon::Float64=1.0)::Float64

Calculate Atkinson inequality index.

The Atkinson index measures inequality with sensitivity parameter ε.

# Arguments
- `incomes::Vector{Float64}`: Income distribution
- `epsilon::Float64`: Inequality aversion parameter (ε ≥ 0)
  - ε = 0: No aversion (Atkinson = 0)
  - ε = 1: Standard aversion
  - ε > 1: High aversion to inequality

# Returns
- `Float64`: Atkinson index (0 = perfect equality, 1 = perfect inequality)
"""
function atkinson_index(incomes::Vector{Float64}; epsilon::Float64=1.0)::Float64
    if any(incomes .< 0)
        throw(ArgumentError("Incomes cannot be negative"))
    end

    if epsilon < 0
        throw(ArgumentError("Epsilon must be non-negative"))
    end

    # Filter out zero incomes
    positive_incomes = filter(x -> x > 0, incomes)

    if isempty(positive_incomes)
        return NaN
    end

    mean_income = mean(positive_incomes)

    if mean_income == 0
        return NaN
    end

    if epsilon == 1.0
        # Special case: geometric mean
        log_mean = mean(log.(positive_incomes))
        equivalent_income = exp(log_mean)
    else
        # General case
        powered = mean(positive_incomes .^ (1 - epsilon))
        equivalent_income = powered ^ (1 / (1 - epsilon))
    end

    atkinson = 1 - (equivalent_income / mean_income)

    return max(0.0, min(1.0, atkinson))
end

"""
    theil_index(incomes::Vector{Float64})::Float64

Calculate Theil T inequality index.

Theil index is an entropy-based measure of inequality.

# Arguments
- `incomes::Vector{Float64}`: Income distribution

# Returns
- `Float64`: Theil index (0 = perfect equality, log(n) = perfect inequality)
"""
function theil_index(incomes::Vector{Float64})::Float64
    if any(incomes .< 0)
        throw(ArgumentError("Incomes cannot be negative"))
    end

    positive_incomes = filter(x -> x > 0, incomes)

    if isempty(positive_incomes)
        return NaN
    end

    mean_income = mean(positive_incomes)

    if mean_income == 0
        return NaN
    end

    # Theil T = (1/n) * Σ(y_i/μ * log(y_i/μ))
    n = length(positive_incomes)
    theil = sum((inc / mean_income) * log(inc / mean_income) for inc in positive_incomes) / n

    return theil
end

"""
    percentile_ratio(incomes::Vector{Float64}, p1::Int=90, p2::Int=10)::Float64

Calculate ratio between two percentiles (e.g., P90/P10).

# Arguments
- `incomes::Vector{Float64}`: Income distribution
- `p1::Int`: Higher percentile (default: 90)
- `p2::Int`: Lower percentile (default: 10)

# Returns
- `Float64`: Ratio of percentiles

# Example
```julia
incomes = [...]
p90_p10 = percentile_ratio(incomes, 90, 10)  # 90th/10th percentile ratio
```
"""
function percentile_ratio(incomes::Vector{Float64}, p1::Int=90, p2::Int=10)::Float64
    if p1 <= p2
        throw(ArgumentError("p1 must be greater than p2"))
    end

    if p1 < 1 || p1 > 99 || p2 < 1 || p2 > 99
        throw(ArgumentError("Percentiles must be between 1 and 99"))
    end

    sorted_incomes = sort(incomes)

    function percentile(data, p)
        n = length(data)
        index = (p / 100) * (n - 1) + 1
        lower_idx = floor(Int, index)
        upper_idx = ceil(Int, index)
        weight = index - lower_idx

        if lower_idx == upper_idx
            return data[lower_idx]
        else
            return data[lower_idx] * (1 - weight) + data[upper_idx] * weight
        end
    end

    high_percentile = percentile(sorted_incomes, p1)
    low_percentile = percentile(sorted_incomes, p2)

    if low_percentile == 0
        return Inf
    end

    return high_percentile / low_percentile
end

"""
    palma_ratio(incomes::Vector{Float64})::Float64

Calculate Palma ratio (top 10% vs bottom 40% income share).

The Palma ratio compares the income share of the richest 10% to the poorest 40%.

# Arguments
- `incomes::Vector{Float64}`: Income distribution

# Returns
- `Float64`: Palma ratio
"""
function palma_ratio(incomes::Vector{Float64})::Float64
    sorted_incomes = sort(incomes)
    n = length(sorted_incomes)

    total_income = sum(sorted_incomes)

    if total_income == 0
        return NaN
    end

    # Top 10%
    top_10_idx = ceil(Int, 0.9 * n)
    top_10_income = sum(sorted_incomes[top_10_idx:end])

    # Bottom 40%
    bottom_40_idx = ceil(Int, 0.4 * n)
    bottom_40_income = sum(sorted_incomes[1:bottom_40_idx])

    if bottom_40_income == 0
        return Inf
    end

    return top_10_income / bottom_40_income
end

"""
    inequality_interpretation(gini::Float64)::String

Provide interpretation of Gini coefficient.
"""
function inequality_interpretation(gini::Float64)::String
    if gini < 0.3
        return "Low inequality (relatively equal distribution)"
    elseif gini < 0.4
        return "Moderate inequality (typical for developed countries)"
    elseif gini < 0.5
        return "High inequality (typical for developing countries)"
    elseif gini < 0.6
        return "Very high inequality"
    else
        return "Extreme inequality (highly unequal distribution)"
    end
end
