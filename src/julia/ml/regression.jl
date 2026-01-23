# SPDX-License-Identifier: PMPL-1.0-or-later
"""
Machine learning regression models for Economic Toolkit.

Basic implementations for economic forecasting and analysis.
"""

using LinearAlgebra
using Statistics

"""
Linear regression model.
"""
struct LinearRegression
    coefficients::Vector{Float64}
    intercept::Float64
    r_squared::Float64
end

"""
Fit linear regression model.

# Arguments
- `X::Matrix{Float64}`: Feature matrix (n_samples × n_features)
- `y::Vector{Float64}`: Target vector

# Returns
- `LinearRegression`: Fitted model
"""
function fit_linear_regression(X::Matrix{Float64}, y::Vector{Float64})::LinearRegression
    n, p = size(X)

    # Add intercept term
    X_with_intercept = hcat(ones(n), X)

    # Solve using normal equations: β = (X'X)^(-1)X'y
    coeffs = (X_with_intercept' * X_with_intercept) \ (X_with_intercept' * y)

    intercept = coeffs[1]
    coefficients = coeffs[2:end]

    # Calculate R²
    y_pred = X_with_intercept * coeffs
    ss_res = sum((y .- y_pred).^2)
    ss_tot = sum((y .- mean(y)).^2)
    r_squared = 1 - ss_res / ss_tot

    return LinearRegression(coefficients, intercept, r_squared)
end

"""
Predict using linear regression model.

# Arguments
- `model::LinearRegression`: Fitted model
- `X::Matrix{Float64}`: Feature matrix

# Returns
- `Vector{Float64}`: Predictions
"""
function predict(model::LinearRegression, X::Matrix{Float64})::Vector{Float64}
    return X * model.coefficients .+ model.intercept
end

"""
Ridge regression (L2 regularization).
"""
struct RidgeRegression
    coefficients::Vector{Float64}
    intercept::Float64
    alpha::Float64
end

"""
Fit ridge regression model.

# Arguments
- `X::Matrix{Float64}`: Feature matrix
- `y::Vector{Float64}`: Target vector
- `alpha::Float64`: Regularization parameter
"""
function fit_ridge_regression(
    X::Matrix{Float64},
    y::Vector{Float64},
    alpha::Float64=1.0
)::RidgeRegression
    n, p = size(X)

    # Standardize features
    X_mean = mean(X, dims=1)
    X_std = std(X, dims=1)
    X_standardized = (X .- X_mean) ./ X_std

    # Add intercept
    X_with_intercept = hcat(ones(n), X_standardized)

    # Ridge regression: β = (X'X + αI)^(-1)X'y
    I_matrix = Matrix{Float64}(I, p+1, p+1)
    I_matrix[1, 1] = 0  # Don't regularize intercept

    coeffs = (X_with_intercept' * X_with_intercept + alpha * I_matrix) \
             (X_with_intercept' * y)

    intercept = coeffs[1]
    coefficients = coeffs[2:end] ./ vec(X_std)

    return RidgeRegression(coefficients, intercept, alpha)
end

"""
Predict using ridge regression model.
"""
function predict(model::RidgeRegression, X::Matrix{Float64})::Vector{Float64}
    return X * model.coefficients .+ model.intercept
end

"""
Cross-validation for model selection.

# Arguments
- `X::Matrix{Float64}`: Feature matrix
- `y::Vector{Float64}`: Target vector
- `k::Int`: Number of folds
- `alpha_values::Vector{Float64}`: Regularization parameters to try

# Returns
- `Float64`: Best alpha value
"""
function cross_validate_ridge(
    X::Matrix{Float64},
    y::Vector{Float64},
    k::Int=5,
    alpha_values::Vector{Float64}=[0.01, 0.1, 1.0, 10.0, 100.0]
)::Float64
    n = size(X, 1)
    fold_size = div(n, k)

    best_alpha = alpha_values[1]
    best_score = Inf

    for alpha in alpha_values
        scores = Float64[]

        for fold in 1:k
            # Split data
            test_start = (fold - 1) * fold_size + 1
            test_end = fold == k ? n : fold * fold_size

            test_idx = test_start:test_end
            train_idx = setdiff(1:n, test_idx)

            X_train, y_train = X[train_idx, :], y[train_idx]
            X_test, y_test = X[test_idx, :], y[test_idx]

            # Fit and evaluate
            model = fit_ridge_regression(X_train, y_train, alpha)
            y_pred = predict(model, X_test)
            mse = mean((y_test .- y_pred).^2)

            push!(scores, mse)
        end

        avg_score = mean(scores)
        if avg_score < best_score
            best_score = avg_score
            best_alpha = alpha
        end
    end

    return best_alpha
end
