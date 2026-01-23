# SPDX-License-Identifier: PMPL-1.0-or-later
"""
End-to-End Integration Tests for Economic Toolkit v10.0

Tests complete workflows across all platforms and features.
"""

using Test, HTTP, JSON3, SQLite, Dates

@testset "Economic Toolkit v10.0 Integration Tests" begin

    @testset "Data Source Integration" begin
        @testset "FRED Data Retrieval" begin
            # Test FRED client
            fred = FREDClient()
            data = fetch_series(fred, "GDPC1", Date(2020, 1, 1), Date(2023, 12, 31))

            @test !isempty(data)
            @test haskey(data, :observations)
            @test length(data.observations) > 0
        end

        @testset "World Bank Data" begin
            wb = WorldBankClient()
            data = fetch_series(wb, "USA", Date(2020, 1, 1), Date(2023, 12, 31))

            @test !isempty(data)
            @test data.country == "USA"
        end

        @testset "Multi-Source Aggregation" begin
            # Test fetching from multiple sources
            sources = ["fred", "worldbank", "imf"]
            results = Dict()

            for source in sources
                client = get_client(source)
                results[source] = fetch_series(client, "test_series", Date(2020, 1, 1), Date(2023, 12, 31))
            end

            @test length(results) == 3
            @test all(haskey(results, s) for s in sources)
        end
    end

    @testset "Formula Calculations" begin
        @testset "GDP Growth" begin
            gdp_values = [100.0, 102.0, 105.0, 108.0, 110.0]
            growth = gdp_growth(gdp_values)

            @test length(growth) == 4
            @test all(g > 0 for g in growth)
        end

        @testset "Gini Coefficient" begin
            incomes = [20000.0, 30000.0, 40000.0, 50000.0, 100000.0, 500000.0]
            gini = gini_coefficient(incomes)

            @test 0 <= gini <= 1
            @test gini > 0.3  # Should show inequality
        end

        @testset "Elasticity" begin
            quantity = [100.0, 90.0, 80.0, 70.0]
            price = [10.0, 11.0, 12.0, 13.0]
            elast = elasticity(quantity, price)

            @test elast < 0  # Downward sloping demand
        end
    end

    @testset "REST API Server" begin
        @testset "Server Startup" begin
            # Start server in background
            server_task = @async start_server(8081, host="127.0.0.1")
            sleep(2)  # Wait for server to start

            @testset "Health Check" begin
                response = HTTP.get("http://127.0.0.1:8081/health")
                @test response.status == 200

                data = JSON3.read(String(response.body))
                @test data.status == "ok"
                @test data.version == "10.0.0"
            end

            @testset "List Data Sources" begin
                response = HTTP.get("http://127.0.0.1:8081/api/v1/sources")
                @test response.status == 200

                sources = JSON3.read(String(response.body))
                @test length(sources) >= 10
                @test any(s.id == "fred" for s in sources)
            end

            @testset "Fetch Series with Auth" begin
                headers = ["Authorization" => "Bearer test-key"]
                response = HTTP.get(
                    "http://127.0.0.1:8081/api/v1/sources/fred/series/GDPC1?start=2020-01-01&end=2023-12-31",
                    headers=headers
                )
                @test response.status == 200
            end

            # Stop server
            schedule(server_task, InterruptException(), error=true)
        end
    end

    @testset "Caching System" begin
        @testset "SQLite Cache" begin
            cache = SQLiteCache(":memory:")

            # Test set and get
            test_key = "test_series_2023"
            test_value = Dict("data" => [1, 2, 3], "metadata" => Dict("source" => "fred"))

            set_cached(cache, test_key, test_value, 3600)
            retrieved = get_cached(cache, test_key)

            @test !isnothing(retrieved)
            @test retrieved.data == [1, 2, 3]
        end

        @testset "Cache Expiration" begin
            cache = SQLiteCache(":memory:")

            set_cached(cache, "expiring_key", "test_value", 1)  # 1 second TTL
            sleep(2)

            @test isnothing(get_cached(cache, "expiring_key"))
        end
    end

    @testset "Machine Learning Integration" begin
        @testset "Linear Regression" begin
            # Generate test data
            X = randn(100, 3)
            true_coeffs = [2.0, -1.5, 0.8]
            y = X * true_coeffs .+ randn(100) * 0.1

            model = fit_linear_regression(X, y)

            @test length(model.coefficients) == 3
            @test model.r_squared > 0.9

            # Test prediction
            X_test = randn(10, 3)
            predictions = predict(model, X_test)
            @test length(predictions) == 10
        end

        @testset "Ridge Regression" begin
            X = randn(50, 10)
            y = randn(50)

            model = fit_ridge_regression(X, y, 1.0)
            @test length(model.coefficients) == 10

            predictions = predict(model, X)
            @test length(predictions) == 50
        end
    end

    @testset "Forecasting Models" begin
        @testset "Exponential Smoothing" begin
            data = cumsum(randn(50))
            forecast = exponential_smoothing(data, 0.3, 5)

            @test length(forecast) == 5
            @test all(isfinite.(forecast))
        end

        @testset "Holt-Winters" begin
            # Generate seasonal data
            t = 1:100
            trend = 0.1 * t
            seasonal = 5 * sin.(2π * t / 12)
            noise = randn(100) * 0.5
            data = trend .+ seasonal .+ noise

            forecast = triple_exponential_smoothing(data, 12, 0.3, 0.1, 0.1, 5)

            @test length(forecast) == 5
            @test all(isfinite.(forecast))
        end
    end

    @testset "Monte Carlo Simulations" begin
        variables = Dict(
            "growth_rate" => Normal(0.025, 0.01),
            "inflation" => Normal(0.02, 0.005)
        )

        model_func = (inputs) -> 100.0 * (1 + inputs["growth_rate"]) / (1 + inputs["inflation"])

        config = MonteCarloConfig(1000, variables, model_func, seed=42)
        results = run_simulation(config)

        @test haskey(results, "mean")
        @test haskey(results, "percentiles")
        @test haskey(results, "var_95")
        @test length(results["results"]) == 1000
    end

    @testset "Authentication & Authorization" begin
        @testset "API Key Generation" begin
            key1 = generate_api_key("etk")
            key2 = generate_api_key("etk")

            @test startswith(key1, "etk_")
            @test startswith(key2, "etk_")
            @test key1 != key2
            @test length(key1) > 40
        end

        @testset "RBAC Permissions" begin
            manager = RBACManager()

            # Create role with permissions
            admin_role = Role(
                "admin",
                [Permission("data", "read"), Permission("data", "write")],
                Dict()
            )
            manager.roles["admin"] = admin_role

            # Create user with role
            user = User("user123", "test@example.com", ["admin"], Dict())
            manager.users["user123"] = user

            # Test permissions
            @test has_permission(manager, "user123", "data", "read")
            @test has_permission(manager, "user123", "data", "write")
            @test !has_permission(manager, "user123", "data", "delete")
        end
    end

    @testset "Internationalization" begin
        @testset "Translation System" begin
            i18n = I18nManager("en-US")

            # Mock translations
            i18n.translations["en-US"] = Dict(
                "welcome" => "Welcome to Economic Toolkit",
                "error.not_found" => "Data not found"
            )

            @test t(i18n, "welcome") == "Welcome to Economic Toolkit"
            @test t(i18n, "error.not_found") == "Data not found"
            @test t(i18n, "missing_key") == "missing_key"
        end

        @testset "Number Formatting" begin
            i18n_us = I18nManager("en-US")
            i18n_de = I18nManager("de-DE")

            value = 1234.56

            us_formatted = format_number(i18n_us, value)
            de_formatted = format_number(i18n_de, value)

            @test us_formatted != de_formatted
        end
    end

    @testset "Performance Benchmarks" begin
        @testset "Large Dataset Processing" begin
            large_data = randn(10000)

            # Benchmark Gini calculation
            @time gini = gini_coefficient(large_data)
            @test 0 <= gini <= 1

            # Benchmark growth rate calculation
            @time growth = growth_rate(large_data[1:1000])
            @test length(growth) == 999
        end

        @testset "Concurrent API Requests" begin
            # Test server can handle concurrent requests
            tasks = [@async HTTP.get("http://127.0.0.1:8081/health") for _ in 1:10]
            responses = [fetch(t) for t in tasks]

            @test all(r.status == 200 for r in responses)
        end
    end
end

println("
╔══════════════════════════════════════════════════════════╗
║  ✅ All Integration Tests Passed - v10.0 Production Ready  ║
╚══════════════════════════════════════════════════════════╝
")
