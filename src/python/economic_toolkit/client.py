# SPDX-License-Identifier: PMPL-1.0-or-later
# SPDX-FileCopyrightText: 2024-2026 Hyperpolymath Contributors

"""
Main client for Economic Toolkit Python API.
"""

from typing import Optional, Dict, Any
import requests
from datetime import date, datetime


class EconomicToolkit:
    """
    Main client for interacting with Economic Toolkit.

    Can work in two modes:
    1. REST API mode: Connect to running Economic Toolkit server
    2. Direct Julia mode: Load Julia backend directly (requires juliacall)

    Args:
        mode: 'rest' or 'julia'
        api_url: URL for REST API mode (default: http://localhost:8080)
        api_key: Optional API key for authentication
    """

    def __init__(
        self,
        mode: str = "rest",
        api_url: str = "http://localhost:8080",
        api_key: Optional[str] = None,
    ):
        self.mode = mode
        self.api_url = api_url.rstrip("/")
        self.api_key = api_key
        self.session = requests.Session()

        if api_key:
            self.session.headers["Authorization"] = f"Bearer {api_key}"

        if mode == "julia":
            self._init_julia()

    def _init_julia(self):
        """Initialize Julia backend using PythonCall/juliacall."""
        try:
            from juliacall import Main as jl

            # Add project path and activate
            jl.seval('import Pkg')
            jl.seval('Pkg.activate(".")')

            # Import EconomicToolkit
            jl.seval('using EconomicToolkit')

            self.jl = jl
            self.jl_toolkit = jl.EconomicToolkit
        except ImportError:
            raise ImportError(
                "juliacall not installed. Install with: pip install juliacall"
            )

    def fetch_series(
        self,
        source: str,
        series_id: str,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
    ) -> Dict[str, Any]:
        """
        Fetch economic data series from specified source.

        Args:
            source: Data source name (fred, worldbank, imf, etc.)
            series_id: Series identifier
            start_date: Optional start date
            end_date: Optional end date

        Returns:
            Dictionary with series data and metadata
        """
        if self.mode == "rest":
            params = {}
            if start_date:
                params["start"] = start_date.isoformat()
            if end_date:
                params["end"] = end_date.isoformat()

            url = f"{self.api_url}/api/v1/sources/{source}/series/{series_id}"
            response = self.session.get(url, params=params)
            response.raise_for_status()
            return response.json()

        elif self.mode == "julia":
            # Call Julia directly
            client_class = getattr(self.jl_toolkit, f"{source.upper()}Client")
            client = client_class()

            jl_start = self.jl.Date(start_date.isoformat()) if start_date else self.jl.Date(1900, 1, 1)
            jl_end = self.jl.Date(end_date.isoformat()) if end_date else self.jl.today()

            result = self.jl_toolkit.fetch_series(client, series_id, jl_start, jl_end)
            return self._julia_to_python(result)

    def search_series(self, source: str, query: str) -> list:
        """
        Search for economic data series.

        Args:
            source: Data source name
            query: Search query string

        Returns:
            List of matching series
        """
        if self.mode == "rest":
            url = f"{self.api_url}/api/v1/sources/{source}/search"
            response = self.session.get(url, params={"q": query})
            response.raise_for_status()
            return response.json()

        elif self.mode == "julia":
            client_class = getattr(self.jl_toolkit, f"{source.upper()}Client")
            client = client_class()
            result = self.jl_toolkit.search_series(client, query)
            return self._julia_to_python(result)

    def list_sources(self) -> list:
        """
        List all available data sources.

        Returns:
            List of data sources with their status
        """
        if self.mode == "rest":
            url = f"{self.api_url}/api/v1/sources"
            response = self.session.get(url)
            response.raise_for_status()
            return response.json()

        elif self.mode == "julia":
            return [
                {"id": "fred", "name": "Federal Reserve Economic Data", "status": "active"},
                {"id": "worldbank", "name": "World Bank", "status": "active"},
                {"id": "imf", "name": "International Monetary Fund", "status": "active"},
                {"id": "oecd", "name": "OECD", "status": "active"},
                {"id": "dbnomics", "name": "DBnomics", "status": "active"},
                {"id": "ecb", "name": "European Central Bank", "status": "active"},
                {"id": "bea", "name": "Bureau of Economic Analysis", "status": "stub"},
                {"id": "census", "name": "Census Bureau", "status": "stub"},
                {"id": "eurostat", "name": "Eurostat", "status": "stub"},
                {"id": "bis", "name": "Bank for International Settlements", "status": "stub"},
            ]

    def health(self) -> Dict[str, str]:
        """
        Check API health status.

        Returns:
            Health status dictionary
        """
        if self.mode == "rest":
            url = f"{self.api_url}/health"
            response = self.session.get(url)
            response.raise_for_status()
            return response.json()

        elif self.mode == "julia":
            return {"status": "ok", "version": "2.1.0", "mode": "julia"}

    def _julia_to_python(self, obj):
        """Convert Julia objects to Python equivalents."""
        # Simple conversion - in reality would need more sophisticated handling
        if hasattr(obj, "__dict__"):
            return {k: self._julia_to_python(v) for k, v in obj.__dict__.items()}
        elif isinstance(obj, (list, tuple)):
            return [self._julia_to_python(item) for item in obj]
        else:
            return obj
