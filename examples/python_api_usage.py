#!/usr/bin/env python3
# SPDX-License-Identifier: PMPL-1.0-or-later
# SPDX-FileCopyrightText: 2024-2026 Hyperpolymath Contributors

"""
Example usage of Economic Toolkit Python API.

This script demonstrates how to use the Python wrapper to access
economic data and perform analysis.
"""

from datetime import date
from economic_toolkit import EconomicToolkit, FRED, WorldBank
from economic_toolkit.formulas import (
    elasticity,
    gdp_growth,
    gini_coefficient,
    lorenz_curve,
    cagr,
)


def example_basic_client():
    """Basic client usage example."""
    print("=== Basic Client Usage ===\n")

    # Initialize client (REST mode, connects to Julia backend)
    client = EconomicToolkit(mode="rest", api_url="http://localhost:8080")

    # Check health
    health = client.health()
    print(f"API Status: {health}")

    # List available data sources
    sources = client.list_sources()
    print(f"\nAvailable sources: {len(sources)}")
    for source in sources:
        print(f"  - {source['name']} ({source['id']}): {source['status']}")


def example_fred_data():
    """FRED data access example."""
    print("\n=== FRED Data Access ===\n")

    # Create FRED client
    fred = FRED()

    # Search for unemployment rate series
    results = fred.search("unemployment rate")
    print(f"Found {len(results)} series matching 'unemployment rate'")

    # Fetch US unemployment rate
    data = fred.fetch(
        "UNRATE",
        start_date=date(2020, 1, 1),
        end_date=date(2023, 12, 31)
    )
    print(f"\nUS Unemployment Rate (2020-2023):")
    print(f"  Series: {data.get('series_id')}")
    print(f"  Points: {len(data.get('observations', []))}")


def example_worldbank_data():
    """World Bank data access example."""
    print("\n=== World Bank Data ===\n")

    wb = WorldBank()

    # Fetch US GDP
    data = wb.fetch(
        "USA",
        start_date=date(2015, 1, 1),
        end_date=date(2023, 12, 31)
    )
    print(f"US GDP data: {data}")


def example_formulas():
    """Economic formulas example."""
    print("\n=== Economic Formulas ===\n")

    # GDP growth calculation
    gdp_values = [100, 102, 105, 108, 110]
    growth_rates = gdp_growth(gdp_values)
    print(f"GDP Growth Rates: {growth_rates}")

    # CAGR calculation
    cagr_value = cagr(beginning_value=100, ending_value=150, num_periods=5)
    print(f"CAGR over 5 years: {cagr_value:.2f}%")

    # Elasticity calculation
    quantity = [100, 90, 80, 70, 60]
    price = [10, 11, 12, 13, 14]
    elast = elasticity(quantity, price, method="point")
    print(f"Price Elasticity of Demand: {elast:.2f}")

    # Gini coefficient (income inequality)
    incomes = [20000, 30000, 40000, 50000, 100000, 500000]
    gini = gini_coefficient(incomes)
    print(f"Gini Coefficient: {gini:.3f}")

    # Lorenz curve
    population, income_share = lorenz_curve(incomes)
    print(f"Lorenz Curve: {len(population)} points")


def example_combined_analysis():
    """Combined analysis example."""
    print("\n=== Combined Analysis ===\n")

    # Fetch GDP data and calculate growth
    print("Fetching GDP data from World Bank...")
    wb = WorldBank()
    # In real usage, would fetch actual data
    # For demo, using dummy data
    gdp_data = [100, 103, 107, 110, 115]

    # Calculate various metrics
    growth = gdp_growth(gdp_data)
    compound_growth = cagr(gdp_data[0], gdp_data[-1], len(gdp_data) - 1)

    print(f"Period-over-period growth rates: {growth}")
    print(f"Compound annual growth rate: {compound_growth:.2f}%")


def main():
    """Run all examples."""
    print("Economic Toolkit Python API Examples")
    print("=" * 60)

    try:
        example_basic_client()
    except Exception as e:
        print(f"Error: {e} (Server may not be running)")

    example_formulas()
    example_combined_analysis()

    print("\n" + "=" * 60)
    print("Examples completed!")


if __name__ == "__main__":
    main()
