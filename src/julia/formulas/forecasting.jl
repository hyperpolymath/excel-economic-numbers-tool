# SPDX-License-Identifier: PMPL-1.0-or-later
"""
Time-series forecasting functions for Economic Toolkit.

Implements ARIMA, exponential smoothing, and seasonal decomposition.
"""

using Statistics
using LinearAlgebra
using FFTW

"""
Simple exponential smoothing forecast.

# Arguments
- `data::Vector{Float64}`: Historical time series data
- `alpha::Float64`: Smoothing parameter (0 < alpha < 1)
- `h::Int`: Forecast horizon

# Returns
- `Vector{Float64}`: Forecasted values
"""
function exponential_smoothing(data::Vector{Float64}, alpha::Float64=0.3, h::Int=1)::Vector{Float64}
    @assert 0 < alpha < 1 "Alpha must be between 0 and 1"
    @assert h > 0 "Forecast horizon must be positive"

    n = length(data)
    level = data[1]
    forecasts = Float64[]

    # Fit the model
    for t in 2:n
        level = alpha * data[t] + (1 - alpha) * level
    end

    # Generate forecasts (flat line for simple exponential smoothing)
    return fill(level, h)
end

"""
Double exponential smoothing (Holt's method) for trend.

# Arguments
- `data::Vector{Float64}`: Historical time series data
- `alpha::Float64`: Level smoothing parameter
- `beta::Float64`: Trend smoothing parameter
- `h::Int`: Forecast horizon
"""
function double_exponential_smoothing(
    data::Vector{Float64},
    alpha::Float64=0.3,
    beta::Float64=0.1,
    h::Int=1
)::Vector{Float64}
    @assert 0 < alpha < 1 && 0 < beta < 1 "Alpha and beta must be between 0 and 1"

    n = length(data)
    level = data[1]
    trend = data[2] - data[1]
    forecasts = Float64[]

    # Fit the model
    for t in 2:n
        prev_level = level
        level = alpha * data[t] + (1 - alpha) * (level + trend)
        trend = beta * (level - prev_level) + (1 - beta) * trend
    end

    # Generate forecasts
    for i in 1:h
        push!(forecasts, level + i * trend)
    end

    return forecasts
end

"""
Triple exponential smoothing (Holt-Winters) for trend and seasonality.

# Arguments
- `data::Vector{Float64}`: Historical time series data
- `period::Int`: Seasonal period
- `alpha::Float64`: Level smoothing parameter
- `beta::Float64`: Trend smoothing parameter
- `gamma::Float64`: Seasonal smoothing parameter
- `h::Int`: Forecast horizon
"""
function triple_exponential_smoothing(
    data::Vector{Float64},
    period::Int,
    alpha::Float64=0.3,
    beta::Float64=0.1,
    gamma::Float64=0.1,
    h::Int=1
)::Vector{Float64}
    @assert period > 0 "Period must be positive"
    @assert length(data) >= 2 * period "Need at least 2 full periods of data"

    n = length(data)

    # Initialize level, trend, and seasonal components
    level = mean(data[1:period])
    trend = (mean(data[period+1:2*period]) - level) / period
    seasonal = data[1:period] .- level

    # Fit the model
    for t in period+1:n
        prev_level = level
        level = alpha * (data[t] - seasonal[mod1(t, period)]) + (1 - alpha) * (level + trend)
        trend = beta * (level - prev_level) + (1 - beta) * trend
        seasonal[mod1(t, period)] = gamma * (data[t] - level) + (1 - gamma) * seasonal[mod1(t, period)]
    end

    # Generate forecasts
    forecasts = Float64[]
    for i in 1:h
        forecast = level + i * trend + seasonal[mod1(n + i, period)]
        push!(forecasts, forecast)
    end

    return forecasts
end

"""
Seasonal decomposition using moving averages.

# Arguments
- `data::Vector{Float64}`: Time series data
- `period::Int`: Seasonal period

# Returns
- `Tuple{Vector{Float64}, Vector{Float64}, Vector{Float64}}`: (trend, seasonal, residual)
"""
function seasonal_decompose(data::Vector{Float64}, period::Int)
    n = length(data)

    # Calculate trend using centered moving average
    trend = zeros(n)
    half_window = div(period, 2)

    for i in half_window+1:n-half_window
        trend[i] = mean(data[i-half_window:i+half_window])
    end

    # Detrended data
    detrended = data .- trend

    # Calculate seasonal component
    seasonal = zeros(n)
    for i in 1:period
        indices = i:period:n
        seasonal[indices] .= mean(detrended[indices])
    end

    # Residual
    residual = data .- trend .- seasonal

    return (trend, seasonal, residual)
end

"""
Simple ARIMA(p,d,q) forecast using basic autoregression.

# Arguments
- `data::Vector{Float64}`: Time series data
- `p::Int`: Autoregressive order
- `d::Int`: Differencing order
- `q::Int`: Moving average order
- `h::Int`: Forecast horizon

Note: This is a simplified implementation. For production use, consider
using a dedicated time-series library.
"""
function arima_forecast(
    data::Vector{Float64},
    p::Int=1,
    d::Int=1,
    q::Int=1,
    h::Int=1
)::Vector{Float64}
    # Apply differencing
    diff_data = copy(data)
    for _ in 1:d
        diff_data = diff(diff_data)
    end

    # Simple AR forecast (ignoring MA component for simplicity)
    n = length(diff_data)
    if n < p
        error("Not enough data for AR($p) model")
    end

    # Fit AR model using least squares
    X = zeros(n - p, p)
    y = diff_data[p+1:end]

    for i in 1:n-p
        X[i, :] = diff_data[i:i+p-1]
    end

    # AR coefficients
    coeffs = X \ y

    # Generate forecasts
    forecasts = Float64[]
    last_values = diff_data[end-p+1:end]

    for _ in 1:h
        next_val = dot(coeffs, last_values)
        push!(forecasts, next_val)
        last_values = vcat(last_values[2:end], next_val)
    end

    # Integrate back if differencing was applied
    for _ in 1:d
        cumsum!(forecasts, vcat([data[end]], forecasts))[2:end]
    end

    return forecasts
end
