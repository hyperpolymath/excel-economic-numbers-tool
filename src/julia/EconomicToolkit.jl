"""
Economic Toolkit v2.0 - Main Module

Cross-platform Excel/LibreOffice add-in for economic modelling and investigative research.
Provides 10+ free data sources, custom economic formulas, and constraint propagation.
"""
module EconomicToolkit

using HTTP
using JSON3
using SQLite
using DataFrames
using Dates
using Statistics
using LinearAlgebra
using SHA

# Export main types
export FREDClient, WorldBankClient, IMFClient, OECDClient, DBnomicsClient, ECBClient
export BEAClient, CensusClient, EurostatClient, BISClient
export fetch_series, search_series

# Export utilities
export RateLimiter, SQLiteCache
export can_proceed, wait_if_needed
export get_cached, set_cached, cache_key

# Export formulas
export elasticity, gdp_growth, lorenz_curve, gini_coefficient
export solve_constraints

# Include utility modules
include("utils/rate_limiter.jl")
include("cache/sqlite_cache.jl")
include("utils/retry.jl")

# Include data source clients
include("data_sources/FRED.jl")
include("data_sources/WorldBank.jl")
include("data_sources/IMF.jl")
include("data_sources/OECD.jl")
include("data_sources/DBnomics.jl")
include("data_sources/ECB.jl")
include("data_sources/BEA.jl")
include("data_sources/Census.jl")
include("data_sources/Eurostat.jl")
include("data_sources/BIS.jl")

# Include formula modules
include("formulas/elasticity.jl")
include("formulas/gdp_growth.jl")
include("formulas/lorenz.jl")
include("formulas/constraints.jl")

"""
    start_server(port::Int=8080; host::String="127.0.0.1")

Start the HTTP API server for the Economic Toolkit.

# Arguments
- `port::Int=8080`: Port to listen on
- `host::String="127.0.0.1"`: Host address to bind to

# API Endpoints

## Data Sources
- `GET /api/v1/sources` - List available data sources
- `GET /api/v1/sources/:source/search?q=query` - Search series
- `GET /api/v1/sources/:source/series/:id?start=date&end=date` - Fetch series data

## Formulas
- `POST /api/v1/formulas/elasticity` - Calculate elasticity
- `POST /api/v1/formulas/growth` - Calculate growth rates
- `POST /api/v1/formulas/gini` - Calculate Gini coefficient

## Constraints
- `POST /api/v1/constraints/solve` - Solve constraint system

## Cache
- `GET /api/v1/cache/stats` - Cache statistics
- `DELETE /api/v1/cache` - Clear cache
"""
function start_server(port::Int=8080; host::String="127.0.0.1")
    @info "Starting Economic Toolkit v2.0 Server" port host

    # Initialize data source clients
    fred = FREDClient()
    wb = WorldBankClient()
    imf = IMFClient()
    oecd = OECDClient()
    dbnomics = DBnomicsClient()
    ecb = ECBClient()

    clients = Dict(
        "fred" => fred,
        "worldbank" => wb,
        "imf" => imf,
        "oecd" => oecd,
        "dbnomics" => dbnomics,
        "ecb" => ecb
    )

    # Router
    router = HTTP.Router()

    # List data sources
    HTTP.register!(router, "GET", "/api/v1/sources") do req
        sources = [
            Dict("id" => "fred", "name" => "Federal Reserve Economic Data", "status" => "active"),
            Dict("id" => "worldbank", "name" => "World Bank", "status" => "active"),
            Dict("id" => "imf", "name" => "International Monetary Fund", "status" => "active"),
            Dict("id" => "oecd", "name" => "OECD", "status" => "active"),
            Dict("id" => "dbnomics", "name" => "DBnomics", "status" => "active"),
            Dict("id" => "ecb", "name" => "European Central Bank", "status" => "active"),
            Dict("id" => "bea", "name" => "Bureau of Economic Analysis", "status" => "stub"),
            Dict("id" => "census", "name" => "Census Bureau", "status" => "stub"),
            Dict("id" => "eurostat", "name" => "Eurostat", "status" => "stub"),
            Dict("id" => "bis", "name" => "Bank for International Settlements", "status" => "stub")
        ]
        return HTTP.Response(200, JSON3.write(sources))
    end

    # Search series
    HTTP.register!(router, "GET", "/api/v1/sources/:source/search") do req
        source = HTTP.URIs.splitpath(req.target)[4]
        query = HTTP.queryparams(HTTP.URI(req.target))["q"]

        if haskey(clients, source)
            results = search_series(clients[source], query)
            return HTTP.Response(200, JSON3.write(results))
        else
            return HTTP.Response(404, JSON3.write(Dict("error" => "Source not found")))
        end
    end

    # Fetch series
    HTTP.register!(router, "GET", "/api/v1/sources/:source/series/:id") do req
        parts = HTTP.URIs.splitpath(req.target)
        source = parts[4]
        series_id = parts[6]
        params = HTTP.queryparams(HTTP.URI(req.target))

        start_date = haskey(params, "start") ? Date(params["start"]) : Date(1900, 1, 1)
        end_date = haskey(params, "end") ? Date(params["end"]) : today()

        if haskey(clients, source)
            data = fetch_series(clients[source], series_id, start_date, end_date)
            return HTTP.Response(200, JSON3.write(data))
        else
            return HTTP.Response(404, JSON3.write(Dict("error" => "Source not found")))
        end
    end

    # Health check
    HTTP.register!(router, "GET", "/health") do req
        HTTP.Response(200, JSON3.write(Dict("status" => "ok", "version" => "2.0.0")))
    end

    # Start server
    HTTP.serve(router, host, port)
end

"""
    main()

Main entry point for command-line execution.
"""
function main()
    # Parse command-line arguments
    args = ARGS

    if "--dev" in args
        @info "Starting in development mode"
        start_server(8080)
    elseif "--help" in args || "-h" in args
        println("""
        Economic Toolkit v2.0

        Usage: julia EconomicToolkit.jl [OPTIONS]

        Options:
            --dev           Start development server on port 8080
            --port PORT     Specify custom port
            --help, -h      Show this help message
        """)
    else
        start_server()
    end
end

# Run main if executed as script
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

end # module
