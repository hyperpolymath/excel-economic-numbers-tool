"""
GDP Growth and Growth Rate Calculations

Provides functions for calculating various growth rates:
- YoY (Year-over-Year)
- QoQ (Quarter-over-Quarter)
- MoM (Month-over-Month)
- CAGR (Compound Annual Growth Rate)
"""

using Dates
using Statistics

"""
    gdp_growth(values::Vector{Float64}, dates::Vector{Date}; method::Symbol=:yoy)::Vector{Float64}

Calculate GDP growth rates using various methods.

# Arguments
- `values::Vector{Float64}`: GDP values
- `dates::Vector{Date}`: Corresponding dates
- `method::Symbol`: Growth calculation method (:yoy, :qoq, :mom, :cagr)

# Returns
- `Vector{Float64}`: Growth rates (as percentages)

# Example
```julia
values = [20000.0, 21000.0, 22000.0]
dates = [Date(2021, 1, 1), Date(2022, 1, 1), Date(2023, 1, 1)]
growth = gdp_growth(values, dates, method=:yoy)
```
"""
function gdp_growth(values::Vector{Float64}, dates::Vector{Date}; method::Symbol=:yoy)::Vector{Float64}
    if length(values) != length(dates)
        throw(ArgumentError("Values and dates must have same length"))
    end

    if length(values) < 2
        throw(ArgumentError("Need at least 2 data points"))
    end

    # Sort by date
    sorted_indices = sortperm(dates)
    sorted_values = values[sorted_indices]
    sorted_dates = dates[sorted_indices]

    if method == :yoy
        return growth_yoy(sorted_values, sorted_dates)
    elseif method == :qoq
        return growth_qoq(sorted_values, sorted_dates)
    elseif method == :mom
        return growth_mom(sorted_values, sorted_dates)
    elseif method == :cagr
        return [growth_cagr(sorted_values, sorted_dates)]
    else
        throw(ArgumentError("Unknown method: $method"))
    end
end

"""
    growth_yoy(values::Vector{Float64}, dates::Vector{Date})::Vector{Float64}

Calculate Year-over-Year growth rates.
Growth = ((Value_t - Value_{t-1year}) / Value_{t-1year}) * 100
"""
function growth_yoy(values::Vector{Float64}, dates::Vector{Date})::Vector{Float64}
    n = length(values)
    growth_rates = Float64[]

    for i in 2:n
        # Find value from approximately 1 year ago
        year_ago = dates[i] - Year(1)
        prev_idx = findlast(d -> d <= year_ago, dates[1:i-1])

        if prev_idx !== nothing
            prev_value = values[prev_idx]
            if prev_value != 0
                growth = ((values[i] - prev_value) / prev_value) * 100
                push!(growth_rates, growth)
            else
                push!(growth_rates, NaN)
            end
        else
            push!(growth_rates, NaN)
        end
    end

    # Pad with NaN for first year
    return vcat([NaN], growth_rates)
end

"""
    growth_qoq(values::Vector{Float64}, dates::Vector{Date})::Vector{Float64}

Calculate Quarter-over-Quarter growth rates (annualized).
QoQ Growth (annualized) = ((Value_t / Value_{t-1})^4 - 1) * 100
"""
function growth_qoq(values::Vector{Float64}, dates::Vector{Date})::Vector{Float64}
    n = length(values)
    growth_rates = Float64[]

    for i in 2:n
        # Find value from approximately 1 quarter ago
        quarter_ago = dates[i] - Month(3)
        prev_idx = findlast(d -> d <= quarter_ago, dates[1:i-1])

        if prev_idx !== nothing
            prev_value = values[prev_idx]
            if prev_value != 0 && values[i] > 0
                # Annualized QoQ growth
                ratio = values[i] / prev_value
                growth = (ratio^4 - 1) * 100
                push!(growth_rates, growth)
            else
                push!(growth_rates, NaN)
            end
        else
            push!(growth_rates, NaN)
        end
    end

    return vcat([NaN], growth_rates)
end

"""
    growth_mom(values::Vector{Float64}, dates::Vector{Date})::Vector{Float64}

Calculate Month-over-Month growth rates (annualized).
MoM Growth (annualized) = ((Value_t / Value_{t-1})^12 - 1) * 100
"""
function growth_mom(values::Vector{Float64}, dates::Vector{Date})::Vector{Float64}
    n = length(values)
    growth_rates = Float64[]

    for i in 2:n
        # Find value from approximately 1 month ago
        month_ago = dates[i] - Month(1)
        prev_idx = findlast(d -> d <= month_ago, dates[1:i-1])

        if prev_idx !== nothing
            prev_value = values[prev_idx]
            if prev_value != 0 && values[i] > 0
                # Annualized MoM growth
                ratio = values[i] / prev_value
                growth = (ratio^12 - 1) * 100
                push!(growth_rates, growth)
            else
                push!(growth_rates, NaN)
            end
        else
            push!(growth_rates, NaN)
        end
    end

    return vcat([NaN], growth_rates)
end

"""
    growth_cagr(values::Vector{Float64}, dates::Vector{Date})::Float64

Calculate Compound Annual Growth Rate over entire period.
CAGR = ((Final_Value / Initial_Value)^(1/years) - 1) * 100
"""
function growth_cagr(values::Vector{Float64}, dates::Vector{Date})::Float64
    if length(values) < 2
        throw(ArgumentError("Need at least 2 data points for CAGR"))
    end

    initial_value = values[1]
    final_value = values[end]
    initial_date = dates[1]
    final_date = dates[end]

    if initial_value <= 0 || final_value <= 0
        return NaN
    end

    # Calculate years (fractional)
    days_diff = (final_date - initial_date).value
    years = days_diff / 365.25

    if years == 0
        return NaN
    end

    cagr = ((final_value / initial_value)^(1/years) - 1) * 100
    return cagr
end

"""
    simple_growth_rate(values::Vector{Float64})::Vector{Float64}

Calculate simple period-over-period growth rates.
Growth_t = ((Value_t - Value_{t-1}) / Value_{t-1}) * 100
"""
function simple_growth_rate(values::Vector{Float64})::Vector{Float64}
    n = length(values)
    growth_rates = Float64[]

    for i in 2:n
        if values[i-1] != 0
            growth = ((values[i] - values[i-1]) / values[i-1]) * 100
            push!(growth_rates, growth)
        else
            push!(growth_rates, NaN)
        end
    end

    return vcat([NaN], growth_rates)
end

"""
    average_growth_rate(values::Vector{Float64})::Float64

Calculate average growth rate across all periods.
"""
function average_growth_rate(values::Vector{Float64})::Float64
    growth_rates = simple_growth_rate(values)
    valid_rates = filter(!isnan, growth_rates)

    if isempty(valid_rates)
        return NaN
    end

    return mean(valid_rates)
end

"""
    real_growth(nominal_values::Vector{Float64}, deflator::Vector{Float64})::Vector{Float64}

Calculate real growth by adjusting for inflation using GDP deflator.

# Arguments
- `nominal_values::Vector{Float64}`: Nominal GDP values
- `deflator::Vector{Float64}`: GDP deflator (base year = 100)

# Returns
- `Vector{Float64}`: Real GDP values
"""
function real_growth(nominal_values::Vector{Float64}, deflator::Vector{Float64})::Vector{Float64}
    if length(nominal_values) != length(deflator)
        throw(ArgumentError("Nominal values and deflator must have same length"))
    end

    real_values = [nominal / (defl / 100) for (nominal, defl) in zip(nominal_values, deflator)]
    return real_values
end

"""
    contribution_to_growth(component_values::Vector{Float64}, total_values::Vector{Float64})::Vector{Float64}

Calculate how much a component contributes to overall growth.

# Example
```julia
# Calculate how much consumption contributes to GDP growth
consumption = [14000.0, 14500.0, 15000.0]
gdp = [20000.0, 21000.0, 22000.0]
contribution = contribution_to_growth(consumption, gdp)
```
"""
function contribution_to_growth(component_values::Vector{Float64}, total_values::Vector{Float64})::Vector{Float64}
    if length(component_values) != length(total_values)
        throw(ArgumentError("Component and total must have same length"))
    end

    n = length(component_values)
    contributions = Float64[]

    for i in 2:n
        component_change = component_values[i] - component_values[i-1]
        prev_total = total_values[i-1]

        if prev_total != 0
            contribution = (component_change / prev_total) * 100
            push!(contributions, contribution)
        else
            push!(contributions, NaN)
        end
    end

    return vcat([NaN], contributions)
end
