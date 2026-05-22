#!/usr/bin/env Rscript
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2024-2026 Hyperpolymath Contributors

# Example usage of Economic Toolkit R package

library(economic.toolkit)

# Basic client usage
cat("=== Basic Client Usage ===\n\n")

# Initialize client (REST mode)
client <- EconomicToolkit(mode = "rest", api_url = "http://localhost:8080")

# Check health (will fail if server not running)
tryCatch({
  health <- client$health()
  cat("API Status:", health$status, "\n")

  # List available data sources
  sources <- client$list_sources()
  cat("\nAvailable sources:", length(sources), "\n")
  for (source in sources) {
    cat(sprintf("  - %s (%s): %s\n", source$name, source$id, source$status))
  }
}, error = function(e) {
  cat("Error:", conditionMessage(e), "(Server may not be running)\n")
})

# FRED data access
cat("\n=== FRED Data Access ===\n\n")

tryCatch({
  fred <- FRED()

  # Fetch US unemployment rate
  data <- fred$fetch("UNRATE", start_date = "2020-01-01", end_date = "2023-12-31")
  cat("US Unemployment Rate (2020-2023) fetched successfully\n")
}, error = function(e) {
  cat("Error:", conditionMessage(e), "\n")
})

# Economic formulas
cat("\n=== Economic Formulas ===\n\n")

# GDP growth calculation
gdp_values <- c(100, 102, 105, 108, 110)
growth_rates <- gdp_growth(gdp_values)
cat("GDP Growth Rates:", paste(round(growth_rates, 2), collapse = ", "), "\n")

# CAGR calculation
cagr_value <- cagr(beginning_value = 100, ending_value = 150, num_periods = 5)
cat("CAGR over 5 years:", round(cagr_value, 2), "%\n")

# Elasticity calculation
quantity <- c(100, 90, 80, 70, 60)
price <- c(10, 11, 12, 13, 14)
elast <- elasticity(quantity, price, method = "point")
cat("Price Elasticity of Demand:", round(elast, 2), "\n")

# Gini coefficient (income inequality)
incomes <- c(20000, 30000, 40000, 50000, 100000, 500000)
gini <- gini_coefficient(incomes)
cat("Gini Coefficient:", round(gini, 3), "\n")

# Lorenz curve
curve <- lorenz_curve(incomes)
cat("Lorenz Curve:", length(curve$cumulative_population), "points\n")

# Plot Lorenz curve if ggplot2 is available
if (requireNamespace("ggplot2", quietly = TRUE)) {
  library(ggplot2)

  df <- data.frame(
    population = curve$cumulative_population,
    income = curve$cumulative_income
  )

  p <- ggplot(df, aes(x = population, y = income)) +
    geom_line(color = "blue", size = 1) +
    geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "red") +
    labs(
      title = "Lorenz Curve",
      x = "Cumulative Share of Population",
      y = "Cumulative Share of Income"
    ) +
    theme_minimal()

  ggsave("lorenz_curve.png", plot = p, width = 8, height = 6)
  cat("\nLorenz curve plot saved to lorenz_curve.png\n")
}

cat("\nExamples completed!\n")
