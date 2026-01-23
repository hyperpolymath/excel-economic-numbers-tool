# SPDX-License-Identifier: PMPL-1.0-or-later
# SPDX-FileCopyrightText: 2024-2026 Hyperpolymath Contributors

"""Tests for Economic Toolkit Python client."""

import pytest
from datetime import date
from economic_toolkit import EconomicToolkit, FRED, WorldBank
from economic_toolkit.formulas import elasticity, gdp_growth, gini_coefficient


class TestEconomicToolkit:
    """Test main client functionality."""

    def test_init_rest_mode(self):
        """Test initialization in REST mode."""
        client = EconomicToolkit(mode="rest")
        assert client.mode == "rest"
        assert client.api_url == "http://localhost:8080"

    def test_init_with_api_key(self):
        """Test initialization with API key."""
        client = EconomicToolkit(api_key="test-key-123")
        assert "Authorization" in client.session.headers
        assert client.session.headers["Authorization"] == "Bearer test-key-123"

    def test_custom_api_url(self):
        """Test custom API URL."""
        client = EconomicToolkit(api_url="https://api.example.com/")
        assert client.api_url == "https://api.example.com"


class TestDataSources:
    """Test data source clients."""

    def test_fred_client(self):
        """Test FRED client initialization."""
        fred = FRED()
        assert fred.source_id == "fred"
        assert fred.source_name == "Federal Reserve Economic Data"

    def test_worldbank_client(self):
        """Test World Bank client initialization."""
        wb = WorldBank()
        assert wb.source_id == "worldbank"
        assert wb.source_name == "World Bank"


class TestFormulas:
    """Test economic formula functions."""

    def test_elasticity_point(self):
        """Test point elasticity calculation."""
        quantity = [100, 90, 80, 70]
        price = [10, 11, 12, 13]
        result = elasticity(quantity, price, method="point")
        assert isinstance(result, float)
        assert result < 0  # Demand curve slopes downward

    def test_elasticity_arc(self):
        """Test arc elasticity calculation."""
        quantity = [100, 80]
        price = [10, 12]
        result = elasticity(quantity, price, method="arc")
        assert isinstance(result, float)

    def test_gdp_growth(self):
        """Test GDP growth rate calculation."""
        gdp = [100, 102, 105, 108]
        growth = gdp_growth(gdp)
        assert len(growth) == 3
        assert all(g > 0 for g in growth)

    def test_gdp_growth_annualized(self):
        """Test annualized GDP growth rate."""
        gdp = [100, 110]
        growth = gdp_growth(gdp, periods=1)
        assert isinstance(growth, float)
        assert growth > 0

    def test_gini_coefficient_equal(self):
        """Test Gini coefficient with equal distribution."""
        incomes = [100, 100, 100, 100]
        gini = gini_coefficient(incomes)
        assert gini < 0.01  # Near perfect equality

    def test_gini_coefficient_unequal(self):
        """Test Gini coefficient with unequal distribution."""
        incomes = [10, 20, 50, 100, 500]
        gini = gini_coefficient(incomes)
        assert 0 < gini < 1


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
