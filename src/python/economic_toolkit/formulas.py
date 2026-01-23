# SPDX-License-Identifier: PMPL-1.0-or-later
# SPDX-FileCopyrightText: 2024-2026 Hyperpolymath Contributors

"""
Economic formula functions for Python API.

Provides economic calculation functions that can work in REST or Julia mode.
"""

from typing import List, Union, Optional
import numpy as np
from economic_toolkit.client import EconomicToolkit


def elasticity(
    quantity: Union[List[float], np.ndarray],
    price: Union[List[float], np.ndarray],
    method: str = "point",
) -> float:
    """
    Calculate price elasticity of demand.

    Args:
        quantity: Quantity values
        price: Price values
        method: 'point' or 'arc' elasticity

    Returns:
        Elasticity coefficient
    """
    if isinstance(quantity, list):
        quantity = np.array(quantity)
    if isinstance(price, list):
        price = np.array(price)

    if method == "point":
        # Point elasticity: (dQ/dP) * (P/Q)
        dq = np.diff(quantity)
        dp = np.diff(price)
        elasticities = (dq / dp) * (price[:-1] / quantity[:-1])
        return float(np.mean(elasticities))

    elif method == "arc":
        # Arc elasticity: ((Q2-Q1)/(Q2+Q1)) / ((P2-P1)/(P2+P1))
        q1, q2 = quantity[0], quantity[-1]
        p1, p2 = price[0], price[-1]
        return ((q2 - q1) / (q2 + q1)) / ((p2 - p1) / (p2 + p1))

    else:
        raise ValueError(f"Unknown method: {method}")


def gdp_growth(
    gdp_values: Union[List[float], np.ndarray],
    periods: Optional[int] = None,
) -> Union[float, np.ndarray]:
    """
    Calculate GDP growth rate(s).

    Args:
        gdp_values: GDP values over time
        periods: Number of periods for annualization (default: None, returns period-over-period)

    Returns:
        Growth rate(s) as percentage
    """
    if isinstance(gdp_values, list):
        gdp_values = np.array(gdp_values)

    # Period-over-period growth
    growth_rates = np.diff(gdp_values) / gdp_values[:-1] * 100

    if periods is None:
        return growth_rates if len(growth_rates) > 1 else float(growth_rates[0])

    # Annualized growth rate
    total_growth = (gdp_values[-1] / gdp_values[0]) ** (1 / periods) - 1
    return float(total_growth * 100)


def gini_coefficient(incomes: Union[List[float], np.ndarray]) -> float:
    """
    Calculate Gini coefficient for income distribution.

    Args:
        incomes: List or array of income values

    Returns:
        Gini coefficient (0 = perfect equality, 1 = perfect inequality)
    """
    if isinstance(incomes, list):
        incomes = np.array(incomes)

    # Sort incomes
    sorted_incomes = np.sort(incomes)
    n = len(sorted_incomes)

    # Calculate Gini coefficient
    cumsum = np.cumsum(sorted_incomes)
    return (2 * np.sum((n - np.arange(n)) * sorted_incomes)) / (n * cumsum[-1]) - (n + 1) / n


def lorenz_curve(incomes: Union[List[float], np.ndarray]) -> tuple:
    """
    Calculate Lorenz curve coordinates.

    Args:
        incomes: List or array of income values

    Returns:
        Tuple of (cumulative_population_share, cumulative_income_share)
    """
    if isinstance(incomes, list):
        incomes = np.array(incomes)

    # Sort incomes
    sorted_incomes = np.sort(incomes)
    n = len(sorted_incomes)

    # Calculate cumulative shares
    cumulative_income = np.cumsum(sorted_incomes) / np.sum(sorted_incomes)
    cumulative_population = np.arange(1, n + 1) / n

    # Add origin point
    cumulative_population = np.concatenate([[0], cumulative_population])
    cumulative_income = np.concatenate([[0], cumulative_income])

    return (cumulative_population.tolist(), cumulative_income.tolist())


def cagr(
    beginning_value: float,
    ending_value: float,
    num_periods: int,
) -> float:
    """
    Calculate Compound Annual Growth Rate (CAGR).

    Args:
        beginning_value: Starting value
        ending_value: Ending value
        num_periods: Number of periods

    Returns:
        CAGR as percentage
    """
    return ((ending_value / beginning_value) ** (1 / num_periods) - 1) * 100


def growth_rate(values: Union[List[float], np.ndarray]) -> Union[float, np.ndarray]:
    """
    Calculate period-over-period growth rates.

    Args:
        values: Time series values

    Returns:
        Growth rates as percentages
    """
    if isinstance(values, list):
        values = np.array(values)

    growth_rates = np.diff(values) / values[:-1] * 100
    return growth_rates if len(growth_rates) > 1 else float(growth_rates[0])
