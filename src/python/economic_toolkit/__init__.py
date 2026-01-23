# SPDX-License-Identifier: PMPL-1.0-or-later
# SPDX-FileCopyrightText: 2024-2026 Hyperpolymath Contributors

"""
Economic Toolkit Python API

Python wrapper for the Economic Toolkit Julia backend.
Provides pythonic access to economic data sources and analysis functions.
"""

__version__ = "2.1.0"
__author__ = "Hyperpolymath Contributors"
__license__ = "PMPL-1.0-or-later"

from economic_toolkit.client import EconomicToolkit
from economic_toolkit.data_sources import (
    FRED,
    WorldBank,
    IMF,
    OECD,
    ECB,
    BEA,
    Census,
    Eurostat,
    BIS,
    DBnomics,
)
from economic_toolkit.formulas import (
    elasticity,
    gdp_growth,
    gini_coefficient,
    lorenz_curve,
    cagr,
    growth_rate,
)

__all__ = [
    "EconomicToolkit",
    "FRED",
    "WorldBank",
    "IMF",
    "OECD",
    "ECB",
    "BEA",
    "Census",
    "Eurostat",
    "BIS",
    "DBnomics",
    "elasticity",
    "gdp_growth",
    "gini_coefficient",
    "lorenz_curve",
    "cagr",
    "growth_rate",
]
