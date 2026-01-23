# SPDX-License-Identifier: PMPL-1.0-or-later
# SPDX-FileCopyrightText: 2024-2026 Hyperpolymath Contributors

"""
Data source client classes for Economic Toolkit.

Provides pythonic interfaces to all supported economic data sources.
"""

from typing import Optional, List, Dict, Any
from datetime import date
from economic_toolkit.client import EconomicToolkit


class DataSourceBase:
    """Base class for all data source clients."""

    source_id: str = ""
    source_name: str = ""

    def __init__(self, client: Optional[EconomicToolkit] = None):
        """
        Initialize data source client.

        Args:
            client: Optional EconomicToolkit client. If None, creates default REST client.
        """
        self.client = client or EconomicToolkit()

    def fetch(
        self,
        series_id: str,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
    ) -> Dict[str, Any]:
        """
        Fetch series data.

        Args:
            series_id: Series identifier
            start_date: Optional start date
            end_date: Optional end date

        Returns:
            Series data dictionary
        """
        return self.client.fetch_series(self.source_id, series_id, start_date, end_date)

    def search(self, query: str) -> List[Dict[str, Any]]:
        """
        Search for series.

        Args:
            query: Search query string

        Returns:
            List of matching series
        """
        return self.client.search_series(self.source_id, query)


class FRED(DataSourceBase):
    """Federal Reserve Economic Data (FRED) client."""

    source_id = "fred"
    source_name = "Federal Reserve Economic Data"


class WorldBank(DataSourceBase):
    """World Bank data client."""

    source_id = "worldbank"
    source_name = "World Bank"


class IMF(DataSourceBase):
    """International Monetary Fund data client."""

    source_id = "imf"
    source_name = "International Monetary Fund"


class OECD(DataSourceBase):
    """OECD data client."""

    source_id = "oecd"
    source_name = "OECD"


class ECB(DataSourceBase):
    """European Central Bank data client."""

    source_id = "ecb"
    source_name = "European Central Bank"


class BEA(DataSourceBase):
    """Bureau of Economic Analysis data client."""

    source_id = "bea"
    source_name = "Bureau of Economic Analysis"


class Census(DataSourceBase):
    """US Census Bureau data client."""

    source_id = "census"
    source_name = "US Census Bureau"


class Eurostat(DataSourceBase):
    """Eurostat data client."""

    source_id = "eurostat"
    source_name = "Eurostat"


class BIS(DataSourceBase):
    """Bank for International Settlements data client."""

    source_id = "bis"
    source_name = "Bank for International Settlements"


class DBnomics(DataSourceBase):
    """DBnomics aggregated data client."""

    source_id = "dbnomics"
    source_name = "DBnomics"
