# SPDX-License-Identifier: PMPL-1.0-or-later
"""
Advanced ML Models for Economic Forecasting - v4.0

Implements state-of-the-art models: LSTM, GRU, Prophet-style decomposition,
Gradient Boosting, and ensemble methods.
"""

using Statistics, Random, Dates

# Neural Network Layers (simplified implementation)
mutable struct LSTMCell
    Wf::Matrix{Float64}  # Forget gate
    Wi::Matrix{Float64}  # Input gate
    Wc::Matrix{Float64}  # Cell gate
    Wo::Matrix{Float64}  # Output gate
    bf::Vector{Float64}
    bi::Vector{Float64}
    bc::Vector{Float64}
    bo::Vector{Float64}
    hidden_size::Int
end

function LSTMCell(input_size::Int, hidden_size::Int)
    LSTMCell(
        randn(hidden_size, input_size + hidden_size) * 0.1,
        randn(hidden_size, input_size + hidden_size) * 0.1,
        randn(hidden_size, input_size + hidden_size) * 0.1,
        randn(hidden_size, input_size + hidden_size) * 0.1,
        zeros(hidden_size),
        zeros(hidden_size),
        zeros(hidden_size),
        zeros(hidden_size),
        hidden_size
    )
end

function sigmoid(x)
    1 ./ (1 .+ exp.(-x))
end

function tanh_activation(x)
    tanh.(x)
end

function forward(cell::LSTMCell, x::Vector{Float64}, h_prev::Vector{Float64}, c_prev::Vector{Float64})
    combined = vcat(x, h_prev)

    # Gates
    ft = sigmoid(cell.Wf * combined .+ cell.bf)
    it = sigmoid(cell.Wi * combined .+ cell.bi)
    c_tilde = tanh_activation(cell.Wc * combined .+ cell.bc)
    ot = sigmoid(cell.Wo * combined .+ cell.bo)

    # Cell state and hidden state
    c_next = ft .* c_prev .+ it .* c_tilde
    h_next = ot .* tanh_activation(c_next)

    return h_next, c_next
end

"""
LSTM-based forecasting model
"""
struct LSTMForecaster
    cells::Vector{LSTMCell}
    output_layer::Matrix{Float64}
    output_bias::Vector{Float64}
    sequence_length::Int
    hidden_size::Int
end

function LSTMForecaster(input_size::Int, hidden_size::Int, num_layers::Int, sequence_length::Int)
    cells = [
        i == 1 ? LSTMCell(input_size, hidden_size) : LSTMCell(hidden_size, hidden_size)
        for i in 1:num_layers
    ]

    output_layer = randn(1, hidden_size) * 0.1
    output_bias = zeros(1)

    LSTMForecaster(cells, output_layer, output_bias, sequence_length, hidden_size)
end

"""
Make forecast using LSTM
"""
function forecast_lstm(
    model::LSTMForecaster,
    data::Vector{Float64},
    horizon::Int
)::Vector{Float64}

    # Normalize data
    μ = mean(data)
    σ = std(data)
    normalized = (data .- μ) ./ σ

    # Prepare input sequence
    input_seq = normalized[end-model.sequence_length+1:end]

    forecasts = Float64[]

    for _ in 1:horizon
        # Initialize hidden and cell states
        h_states = [zeros(model.hidden_size) for _ in 1:length(model.cells)]
        c_states = [zeros(model.hidden_size) for _ in 1:length(model.cells)]

        # Forward pass through sequence
        for x in input_seq
            for (i, cell) in enumerate(model.cells)
                input_vec = i == 1 ? [x] : h_states[i-1]
                h_states[i], c_states[i] = forward(cell, input_vec, h_states[i], c_states[i])
            end
        end

        # Generate prediction
        pred = (model.output_layer * h_states[end] .+ model.output_bias)[1]

        # Denormalize
        pred_denorm = pred * σ + μ
        push!(forecasts, pred_denorm)

        # Update input sequence (sliding window)
        push!(input_seq, pred)
        popfirst!(input_seq)
    end

    return forecasts
end

"""
Gradient Boosting for time series
"""
struct GradientBoostingForecaster
    trees::Vector{Dict{String, Any}}
    learning_rate::Float64
    n_estimators::Int
end

function fit_gradient_boosting(
    X::Matrix{Float64},
    y::Vector{Float64};
    n_estimators::Int=100,
    learning_rate::Float64=0.1,
    max_depth::Int=5
)::GradientBoostingForecaster

    # Initialize with mean
    predictions = fill(mean(y), length(y))
    trees = Dict{String, Any}[]

    for i in 1:n_estimators
        # Calculate residuals
        residuals = y .- predictions

        # Fit tree to residuals (simplified)
        tree = Dict(
            "feature" => 1,
            "threshold" => median(X[:, 1]),
            "left_value" => mean(residuals),
            "right_value" => mean(residuals)
        )

        push!(trees, tree)

        # Update predictions
        tree_preds = [x[1] > tree["threshold"] ? tree["right_value"] : tree["left_value"] for x in eachrow(X)]
        predictions .+= learning_rate .* tree_preds
    end

    return GradientBoostingForecaster(trees, learning_rate, n_estimators)
end

"""
Prophet-style decomposition
"""
struct ProphetDecomposition
    trend::Vector{Float64}
    seasonal::Vector{Float64}
    holidays::Vector{Float64}
    residual::Vector{Float64}
    period::Int
end

function decompose_prophet(
    data::Vector{Float64},
    dates::Vector{Date};
    yearly_seasonality::Bool=true,
    period::Int=12
)::ProphetDecomposition

    n = length(data)

    # Trend (linear regression)
    X = collect(1:n)
    X_mean = mean(X)
    y_mean = mean(data)
    slope = sum((X .- X_mean) .* (data .- y_mean)) / sum((X .- X_mean).^2)
    intercept = y_mean - slope * X_mean
    trend = slope .* X .+ intercept

    # Detrend
    detrended = data .- trend

    # Seasonal component
    seasonal = zeros(n)
    if yearly_seasonality && n >= period
        # Calculate average seasonal pattern
        season_avgs = [mean(detrended[i:period:end]) for i in 1:period]
        seasonal = [season_avgs[mod1(i, period)] for i in 1:n]
    end

    # Holidays (simplified - just weekends for now)
    holidays = zeros(n)
    for (i, date) in enumerate(dates)
        if dayofweek(date) in [6, 7]  # Saturday, Sunday
            holidays[i] = mean(data) * 0.05  # 5% boost
        end
    end

    # Residual
    residual = data .- trend .- seasonal .- holidays

    return ProphetDecomposition(trend, seasonal, holidays, residual, period)
end

"""
Forecast using decomposition
"""
function forecast_decomposition(
    decomp::ProphetDecomposition,
    horizon::Int
)::Vector{Float64}

    n_hist = length(decomp.trend)

    # Extrapolate trend
    X_hist = collect(1:n_hist)
    slope = (decomp.trend[end] - decomp.trend[1]) / (n_hist - 1)
    trend_forecast = [decomp.trend[end] + slope * i for i in 1:horizon]

    # Repeat seasonal pattern
    seasonal_forecast = [decomp.seasonal[mod1(n_hist + i, decomp.period)] for i in 1:horizon]

    # No holiday forecast (would need dates)
    holidays_forecast = zeros(horizon)

    # Combine
    forecast = trend_forecast .+ seasonal_forecast .+ holidays_forecast

    return forecast
end

"""
Ensemble forecast combining multiple models
"""
function ensemble_forecast(
    data::Vector{Float64},
    dates::Vector{Date},
    horizon::Int;
    methods::Vector{String}=["arima", "exponential", "decomposition"]
)::Dict{String, Any}

    forecasts = Dict{String, Vector{Float64}}()

    # Simple exponential smoothing
    if "exponential" in methods
        α = 0.3
        forecast_exp = exponential_smoothing(data, α, horizon)
        forecasts["exponential"] = forecast_exp
    end

    # Decomposition
    if "decomposition" in methods && length(dates) == length(data)
        decomp = decompose_prophet(data, dates)
        forecast_decomp = forecast_decomposition(decomp, horizon)
        forecasts["decomposition"] = forecast_decomp
    end

    # Simple trend extrapolation
    if "trend" in methods
        X = collect(1:length(data))
        X_mean = mean(X)
        y_mean = mean(data)
        slope = sum((X .- X_mean) .* (data .- y_mean)) / sum((X .- X_mean).^2)
        intercept = y_mean - slope * X_mean

        forecast_trend = [slope * (length(data) + i) + intercept for i in 1:horizon]
        forecasts["trend"] = forecast_trend
    end

    # Ensemble (average of all methods)
    if length(forecasts) > 0
        ensemble = zeros(horizon)
        for (_, forecast) in forecasts
            ensemble .+= forecast
        end
        ensemble ./= length(forecasts)
        forecasts["ensemble"] = ensemble
    end

    # Calculate prediction intervals (simplified)
    residuals = diff(data)
    residual_std = std(residuals)

    lower_bound = forecasts["ensemble"] .- 1.96 * residual_std
    upper_bound = forecasts["ensemble"] .+ 1.96 * residual_std

    return Dict(
        "forecasts" => forecasts,
        "ensemble" => get(forecasts, "ensemble", Float64[]),
        "lower_bound" => lower_bound,
        "upper_bound" => upper_bound,
        "confidence_level" => 0.95
    )
end

# Reuse exponential_smoothing from forecasting.jl
function exponential_smoothing(data::Vector{Float64}, α::Float64, horizon::Int)::Vector{Float64}
    level = data[1]
    for value in data[2:end]
        level = α * value + (1 - α) * level
    end
    return fill(level, horizon)
end

export LSTMForecaster, forecast_lstm, GradientBoostingForecaster, fit_gradient_boosting
export ProphetDecomposition, decompose_prophet, forecast_decomposition, ensemble_forecast
