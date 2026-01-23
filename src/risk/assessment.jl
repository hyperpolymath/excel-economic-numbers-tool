# SPDX-License-Identifier: PMPL-1.0-or-later
"""
Risk Assessment Tools - v4.0

Value at Risk (VaR), Conditional VaR, stress testing, and risk metrics.
"""

using Statistics, Distributions

struct RiskMetrics
    var_95::Float64  # Value at Risk at 95% confidence
    var_99::Float64  # Value at Risk at 99% confidence
    cvar_95::Float64  # Conditional VaR (Expected Shortfall) at 95%
    cvar_99::Float64  # Conditional VaR at 99%
    max_drawdown::Float64
    sharpe_ratio::Float64
    volatility::Float64
    skewness::Float64
    kurtosis::Float64
end

struct StressTestResult
    scenario_name::String
    baseline_value::Float64
    stressed_value::Float64
    loss_amount::Float64
    loss_percent::Float64
    passed::Bool
end

"""
Calculate Value at Risk (VaR) using historical method
"""
function calculate_var(
    returns::Vector{Float64},
    confidence::Float64=0.95
)::Float64

    if isempty(returns)
        return 0.0
    end

    # Sort returns
    sorted = sort(returns)

    # Find percentile
    index = Int(ceil((1 - confidence) * length(sorted)))
    index = max(1, min(index, length(sorted)))

    return -sorted[index]  # Negative because we want loss
end

"""
Calculate Conditional VaR (CVaR / Expected Shortfall)
"""
function calculate_cvar(
    returns::Vector{Float64},
    confidence::Float64=0.95
)::Float64

    if isempty(returns)
        return 0.0
    end

    # Sort returns
    sorted = sort(returns)

    # Find cutoff
    index = Int(ceil((1 - confidence) * length(sorted)))
    index = max(1, min(index, length(sorted)))

    # Average of all returns below VaR threshold
    tail_returns = sorted[1:index]

    return -mean(tail_returns)
end

"""
Calculate maximum drawdown
"""
function calculate_max_drawdown(values::Vector{Float64})::Float64
    if length(values) < 2
        return 0.0
    end

    max_dd = 0.0
    peak = values[1]

    for value in values
        if value > peak
            peak = value
        end

        dd = (peak - value) / peak
        if dd > max_dd
            max_dd = dd
        end
    end

    return max_dd
end

"""
Calculate Sharpe ratio
"""
function calculate_sharpe_ratio(
    returns::Vector{Float64},
    risk_free_rate::Float64=0.02
)::Float64

    if isempty(returns) || std(returns) == 0.0
        return 0.0
    end

    excess_returns = returns .- (risk_free_rate / length(returns))
    return mean(excess_returns) / std(excess_returns)
end

"""
Calculate skewness
"""
function calculate_skewness(values::Vector{Float64})::Float64
    if length(values) < 3
        return 0.0
    end

    n = length(values)
    μ = mean(values)
    σ = std(values)

    if σ == 0.0
        return 0.0
    end

    m3 = sum((values .- μ).^3) / n
    return m3 / σ^3
end

"""
Calculate excess kurtosis
"""
function calculate_kurtosis(values::Vector{Float64})::Float64
    if length(values) < 4
        return 0.0
    end

    n = length(values)
    μ = mean(values)
    σ = std(values)

    if σ == 0.0
        return 0.0
    end

    m4 = sum((values .- μ).^4) / n
    return (m4 / σ^4) - 3.0  # Excess kurtosis (subtract 3 for normal distribution)
end

"""
Comprehensive risk metrics
"""
function assess_risk(
    values::Vector{Float64},
    risk_free_rate::Float64=0.02
)::RiskMetrics

    # Calculate returns
    returns = length(values) > 1 ? diff(values) ./ values[1:end-1] : Float64[]

    if isempty(returns)
        return RiskMetrics(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
    end

    var_95 = calculate_var(returns, 0.95)
    var_99 = calculate_var(returns, 0.99)
    cvar_95 = calculate_cvar(returns, 0.95)
    cvar_99 = calculate_cvar(returns, 0.99)
    max_dd = calculate_max_drawdown(values)
    sharpe = calculate_sharpe_ratio(returns, risk_free_rate)
    volatility = std(returns)
    skew = calculate_skewness(returns)
    kurt = calculate_kurtosis(returns)

    return RiskMetrics(
        var_95, var_99, cvar_95, cvar_99,
        max_dd, sharpe, volatility, skew, kurt
    )
end

"""
Stress testing - apply extreme scenarios
"""
function stress_test(
    base_value::Float64,
    stress_scenarios::Dict{String, Float64};
    loss_threshold::Float64=0.1  # 10% loss threshold for "pass"
)::Vector{StressTestResult}

    results = StressTestResult[]

    for (scenario_name, shock) in stress_scenarios
        stressed_value = base_value * (1 + shock)
        loss_amount = base_value - stressed_value
        loss_percent = -shock * 100
        passed = abs(shock) <= loss_threshold

        push!(results, StressTestResult(
            scenario_name,
            base_value,
            stressed_value,
            loss_amount,
            loss_percent,
            passed
        ))
    end

    # Sort by loss severity
    sort!(results, by=r -> r.loss_percent, rev=true)

    return results
end

"""
Parametric VaR using normal distribution
"""
function parametric_var(
    mean_return::Float64,
    volatility::Float64,
    confidence::Float64=0.95,
    time_horizon::Int=1
)::Float64

    # Z-score for confidence level
    z = quantile(Normal(), 1 - confidence)

    # VaR = μ - z*σ*√t
    var = -(mean_return * time_horizon - z * volatility * sqrt(time_horizon))

    return var
end

"""
Monte Carlo VaR simulation
"""
function monte_carlo_var(
    mean_return::Float64,
    volatility::Float64,
    initial_value::Float64,
    confidence::Float64=0.95;
    n_simulations::Int=10000,
    time_horizon::Int=1
)::Float64

    simulated_returns = Float64[]

    for _ in 1:n_simulations
        # Simulate path using geometric Brownian motion
        final_value = initial_value

        for _ in 1:time_horizon
            random_return = rand(Normal(mean_return, volatility))
            final_value *= (1 + random_return)
        end

        total_return = (final_value - initial_value) / initial_value
        push!(simulated_returns, total_return)
    end

    return calculate_var(simulated_returns, confidence)
end

"""
Generate risk report
"""
function generate_risk_report(metrics::RiskMetrics, values::Vector{Float64})::String
    report = """
    # Risk Assessment Report

    Generated: $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))

    ## Risk Metrics

    ### Value at Risk (VaR)
    - **95% VaR:** $(round(metrics.var_95 * 100, digits=2))%
    - **99% VaR:** $(round(metrics.var_99 * 100, digits=2))%

    **Interpretation:** There is a 5% chance of losing more than $(round(metrics.var_95 * 100, digits=2))%
    and a 1% chance of losing more than $(round(metrics.var_99 * 100, digits=2))%.

    ### Conditional Value at Risk (CVaR / Expected Shortfall)
    - **95% CVaR:** $(round(metrics.cvar_95 * 100, digits=2))%
    - **99% CVaR:** $(round(metrics.cvar_99 * 100, digits=2))%

    **Interpretation:** When losses exceed the VaR threshold, the expected loss is $(round(metrics.cvar_95 * 100, digits=2))%.

    ### Volatility and Risk-Adjusted Returns
    - **Volatility (Annualized):** $(round(metrics.volatility * 100, digits=2))%
    - **Sharpe Ratio:** $(round(metrics.sharpe_ratio, digits=3))
    - **Maximum Drawdown:** $(round(metrics.max_drawdown * 100, digits=2))%

    ### Distribution Characteristics
    - **Skewness:** $(round(metrics.skewness, digits=3))
      $(metrics.skewness < 0 ? "Negative skew (left tail risk)" : "Positive skew (right tail opportunity)")
    - **Excess Kurtosis:** $(round(metrics.kurtosis, digits=3))
      $(metrics.kurtosis > 0 ? "Fat tails (more extreme events than normal)" : "Thin tails")

    ## Data Summary
    - **Observations:** $(length(values))
    - **Mean:** $(round(mean(values), digits=2))
    - **Std Dev:** $(round(std(values), digits=2))
    - **Min:** $(round(minimum(values), digits=2))
    - **Max:** $(round(maximum(values), digits=2))

    ## Risk Assessment

    """

    # Risk level classification
    risk_level = if metrics.var_95 < 0.05
        "LOW"
    elseif metrics.var_95 < 0.15
        "MODERATE"
    else
        "HIGH"
    end

    report *= """
    **Overall Risk Level:** $risk_level

    """

    return report
end

export RiskMetrics, StressTestResult
export calculate_var, calculate_cvar, calculate_max_drawdown, calculate_sharpe_ratio
export assess_risk, stress_test, parametric_var, monte_carlo_var, generate_risk_report
