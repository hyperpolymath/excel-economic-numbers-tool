"""
BEA (Bureau of Economic Analysis) Client

Fetches economic data from the U.S. Bureau of Economic Analysis API.

API Documentation: https://apps.bea.gov/api/
Rate Limit: 100 requests per minute (with API key)
API Key: Optional but recommended (higher limits)

Supported Datasets:
- NIPA (National Income and Product Accounts) - GDP, Personal Income, etc.
- NIUnderlyingDetail - Detailed NIPA tables
- MNE - Multinational Enterprises
- FixedAssets - Fixed Assets tables
- ITA (International Transactions) - Balance of Payments
- IIP (International Investment Position)
- Regional - State and metro area data

Example:
```julia
client = BEAClient(api_key="YOUR_API_KEY")
# Fetch Table 1.1.5 - Gross Domestic Product
gdp = fetch_series(client, "NIPA:T10105:A191RC", Date(2020, 1, 1), Date(2023, 12, 31))
```
"""

using HTTP
using JSON3
using Dates
using DataFrames

struct BEAClient
    base_url::String
    api_key::Union{String, Nothing}
    rate_limiter::RateLimiter
    cache::SQLiteCache
    retry_config::RetryConfig

    function BEAClient(;
        api_key::Union{String, Nothing}=get(ENV, "BEA_API_KEY", nothing),
        cache_ttl::Int=86400
    )
        if api_key === nothing
            @warn "BEA API key not provided. Some features may be limited. Get a key at https://apps.bea.gov/api/signup/"
        end

        base_url = "https://apps.bea.gov/api/data"
        rate_limiter = RateLimiter(api_key !== nothing ? 100 : 30)  # Higher limit with API key
        cache = SQLiteCache(default_ttl=cache_ttl)
        retry_config = RetryConfig()

        new(base_url, api_key, rate_limiter, cache, retry_config)
    end
end

"""
Parse BEA series ID in format: DATASET:TABLE:LINE
Examples:
- "NIPA:T10105:A191RC" - NIPA Table 1.1.5, Line A191RC (GDP)
- "Regional:SQGDP:1:ALL" - Regional GDP for all states
"""
function parse_series_id(series_id::String)::Dict{String, String}
    parts = split(series_id, ":")
    if length(parts) < 2
        throw(ArgumentError("Invalid BEA series ID format. Expected DATASET:TABLE[:LINE]"))
    end

    dataset = parts[1]
    table = parts[2]
    line = length(parts) >= 3 ? parts[3] : ""

    return Dict("dataset" => dataset, "table" => table, "line" => line)
end

"""
Fetch data series from BEA API

Arguments:
- client: BEAClient instance
- series_id: Series identifier (format: DATASET:TABLE:LINE)
- start_date: Start date for data
- end_date: End date for data

Returns DataFrame with columns: date, value, series_id
"""
function fetch_series(client::BEAClient, series_id::String, start_date::Date, end_date::Date)::DataFrame
    # Check cache first
    key = cache_key("bea", series_id, start_date, end_date)
    cached = get_cached(client.cache, key)
    if cached !== nothing
        @info "Returning cached BEA data for series: $series_id"
        return parse_bea_response(cached, series_id)
    end

    # Rate limit
    wait_if_needed(client.rate_limiter)

    # Parse series ID
    parsed = parse_series_id(series_id)
    dataset = parsed["dataset"]
    table = parsed["table"]
    line = parsed["line"]

    # Build API request
    start_year = Dates.year(start_date)
    end_year = Dates.year(end_date)

    params = Dict(
        "UserID" => client.api_key !== nothing ? client.api_key : "DEMO_KEY",
        "method" => "GetData",
        "datasetname" => dataset,
        "TableName" => table,
        "Frequency" => "A",  # Annual (could be Q for quarterly, M for monthly)
        "Year" => "X",  # X means all years
        "ResultFormat" => "JSON"
    )

    if line != ""
        params["LineCode"] = line
    end

    # Make request with retry logic
    fetch_func = () -> begin
        response = HTTP.get(client.base_url, query=params)
        if response.status != 200
            throw(HTTPError(response.status, "BEA API returned status $(response.status)"))
        end
        return String(response.body)
    end

    try
        json_str = with_retry(fetch_func, client.retry_config)

        # Cache the result
        set_cached(client.cache, key, json_str)

        # Parse and return
        return parse_bea_response(json_str, series_id)
    catch e
        @warn "BEA API request failed: $e"
        # Try to return cached data if available
        cached = get_cached(client.cache, key, ignore_ttl=true)
        if cached !== nothing
            @info "Returning expired cache data due to API failure"
            return parse_bea_response(cached, series_id)
        end
        rethrow(e)
    end
end

"""
Parse BEA JSON response into DataFrame
"""
function parse_bea_response(json_str::String, series_id::String)::DataFrame
    data = JSON3.read(json_str)

    # BEA API structure: BEAAPI.Results.Data
    if !haskey(data, "BEAAPI")
        throw(ArgumentError("Invalid BEA API response format"))
    end

    results = data["BEAAPI"]["Results"]

    if haskey(results, "Error")
        error_msg = results["Error"]["APIErrorDescription"]
        throw(HTTPError(400, "BEA API error: $error_msg"))
    end

    observations = results["Data"]

    # Parse observations
    dates = Date[]
    values = Float64[]

    for obs in observations
        # BEA uses different date fields depending on frequency
        date_str = haskey(obs, "TimePeriod") ? obs["TimePeriod"] : obs["Year"]

        # Parse date (handle different formats)
        date = if occursin("Q", date_str)
            # Quarterly: "2023Q1"
            year = parse(Int, split(date_str, "Q")[1])
            quarter = parse(Int, split(date_str, "Q")[2])
            Date(year, (quarter - 1) * 3 + 1, 1)
        elseif occursin("M", date_str)
            # Monthly: "2023M01"
            year = parse(Int, split(date_str, "M")[1])
            month = parse(Int, split(date_str, "M")[2])
            Date(year, month, 1)
        else
            # Annual: "2023"
            Date(parse(Int, date_str), 1, 1)
        end

        # Parse value
        value_str = obs["DataValue"]
        value = value_str == "" ? missing : parse(Float64, replace(value_str, "," => ""))

        push!(dates, date)
        push!(values, ismissing(value) ? NaN : value)
    end

    return DataFrame(
        date = dates,
        value = values,
        series_id = fill(series_id, length(dates))
    )
end

"""
Search for BEA data series

Note: BEA API doesn't have a direct search endpoint. This function searches
through available datasets and tables.
"""
function search_series(client::BEAClient, query::String; limit::Int=100)::Vector{Dict}
    # Rate limit
    wait_if_needed(client.rate_limiter)

    # For now, return a curated list of common series
    # In a full implementation, this would query the GetParameterValues endpoint
    common_series = [
        Dict(
            "id" => "NIPA:T10105:A191RC",
            "title" => "Gross Domestic Product",
            "dataset" => "NIPA",
            "frequency" => "Annual",
            "units" => "Billions of Dollars"
        ),
        Dict(
            "id" => "NIPA:T10106:A191RX",
            "title" => "Real Gross Domestic Product",
            "dataset" => "NIPA",
            "frequency" => "Annual",
            "units" => "Billions of Chained 2017 Dollars"
        ),
        Dict(
            "id" => "NIPA:T20100:DPCERC",
            "title" => "Personal Consumption Expenditures",
            "dataset" => "NIPA",
            "frequency" => "Annual",
            "units" => "Billions of Dollars"
        ),
        Dict(
            "id" => "NIPA:T50500:A191RC",
            "title" => "Gross Domestic Product by Industry",
            "dataset" => "NIPA",
            "frequency" => "Annual",
            "units" => "Billions of Dollars"
        ),
        Dict(
            "id" => "Regional:SQGDP:1:ALL",
            "title" => "State GDP - All States",
            "dataset" => "Regional",
            "frequency" => "Quarterly",
            "units" => "Millions of Dollars"
        ),
    ]

    # Filter by query
    query_lower = lowercase(query)
    filtered = filter(s -> occursin(query_lower, lowercase(s["title"])) ||
                           occursin(query_lower, lowercase(s["id"])),
                      common_series)

    return first(filtered, limit)
end

"""
Get available datasets from BEA
"""
function get_datasets(client::BEAClient)::Vector{String}
    return ["NIPA", "NIUnderlyingDetail", "MNE", "FixedAssets", "ITA", "IIP", "Regional"]
end

"""
Get available tables for a dataset
"""
function get_tables(client::BEAClient, dataset::String)::Vector{String}
    # This would query GetParameterList endpoint in full implementation
    # For now, return common tables for NIPA
    if dataset == "NIPA"
        return ["T10105", "T10106", "T20100", "T20200", "T50100", "T50500"]
    else
        return String[]
    end
end
