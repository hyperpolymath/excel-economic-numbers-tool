# SPDX-License-Identifier: PMPL-1.0-or-later
# SPDX-FileCopyrightText: 2024-2026 Hyperpolymath Contributors

#' Calculate Price Elasticity of Demand
#'
#' @param quantity Numeric vector of quantity values
#' @param price Numeric vector of price values
#' @param method Character string: 'point' or 'arc'. Default: 'point'
#'
#' @return Numeric elasticity coefficient
#' @export
#'
#' @examples
#' quantity <- c(100, 90, 80, 70)
#' price <- c(10, 11, 12, 13)
#' elasticity(quantity, price, method = "point")
elasticity <- function(quantity, price, method = "point") {
  if (method == "point") {
    dq <- diff(quantity)
    dp <- diff(price)
    elasticities <- (dq / dp) * (price[-length(price)] / quantity[-length(quantity)])
    return(mean(elasticities))
  } else if (method == "arc") {
    q1 <- quantity[1]
    q2 <- quantity[length(quantity)]
    p1 <- price[1]
    p2 <- price[length(price)]
    return(((q2 - q1) / (q2 + q1)) / ((p2 - p1) / (p2 + p1)))
  } else {
    stop("Unknown method: ", method)
  }
}

#' Calculate GDP Growth Rate
#'
#' @param gdp_values Numeric vector of GDP values over time
#' @param periods Optional integer: number of periods for annualization
#'
#' @return Numeric growth rate(s) as percentage
#' @export
#'
#' @examples
#' gdp <- c(100, 102, 105, 108, 110)
#' gdp_growth(gdp)
#' gdp_growth(gdp, periods = 4)
gdp_growth <- function(gdp_values, periods = NULL) {
  growth_rates <- diff(gdp_values) / gdp_values[-length(gdp_values)] * 100

  if (is.null(periods)) {
    return(growth_rates)
  } else {
    total_growth <- (gdp_values[length(gdp_values)] / gdp_values[1]) ^ (1 / periods) - 1
    return(total_growth * 100)
  }
}

#' Calculate Gini Coefficient
#'
#' @param incomes Numeric vector of income values
#'
#' @return Numeric Gini coefficient (0 = perfect equality, 1 = perfect inequality)
#' @export
#'
#' @examples
#' incomes <- c(20000, 30000, 40000, 50000, 100000, 500000)
#' gini_coefficient(incomes)
gini_coefficient <- function(incomes) {
  sorted_incomes <- sort(incomes)
  n <- length(sorted_incomes)
  cumsum_incomes <- cumsum(sorted_incomes)

  gini <- (2 * sum((n - seq_along(sorted_incomes) + 1) * sorted_incomes)) /
    (n * cumsum_incomes[n]) - (n + 1) / n

  return(gini)
}

#' Calculate Lorenz Curve Coordinates
#'
#' @param incomes Numeric vector of income values
#'
#' @return List with cumulative_population and cumulative_income vectors
#' @export
#'
#' @examples
#' incomes <- c(20000, 30000, 40000, 50000, 100000, 500000)
#' curve <- lorenz_curve(incomes)
#' plot(curve$cumulative_population, curve$cumulative_income, type = "l")
lorenz_curve <- function(incomes) {
  sorted_incomes <- sort(incomes)
  n <- length(sorted_incomes)

  cumulative_income <- cumsum(sorted_incomes) / sum(sorted_incomes)
  cumulative_population <- seq_len(n) / n

  # Add origin point
  cumulative_population <- c(0, cumulative_population)
  cumulative_income <- c(0, cumulative_income)

  return(list(
    cumulative_population = cumulative_population,
    cumulative_income = cumulative_income
  ))
}

#' Calculate Compound Annual Growth Rate (CAGR)
#'
#' @param beginning_value Numeric starting value
#' @param ending_value Numeric ending value
#' @param num_periods Integer number of periods
#'
#' @return Numeric CAGR as percentage
#' @export
#'
#' @examples
#' cagr(100, 150, 5)
cagr <- function(beginning_value, ending_value, num_periods) {
  return(((ending_value / beginning_value) ^ (1 / num_periods) - 1) * 100)
}

#' Calculate Period-over-Period Growth Rates
#'
#' @param values Numeric vector of time series values
#'
#' @return Numeric vector of growth rates as percentages
#' @export
#'
#' @examples
#' values <- c(100, 105, 110, 108, 115)
#' growth_rate(values)
growth_rate <- function(values) {
  return(diff(values) / values[-length(values)] * 100)
}
