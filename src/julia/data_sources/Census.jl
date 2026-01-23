"""
U.S. Census Bureau Client

Fetches economic and demographic data from the U.S. Census Bureau API.

API Documentation: https://www.census.gov/data/developers/data-sets.html
Rate Limit: 500 requests per IP per day (without key), 5000 per day (with key)
API Key: Optional but recommended

Supported Datasets:
- Economic Indicators (timeseries) - Retail sales, housing starts, etc.
- ACS (American Community Survey) - Demographics, income, housing
- Population Estimates - State and county population
- International Trade - Import/export data
- CBP (County Business Patterns) - Employment and establishments by industry

Example:
```julia
client = CensusClient(api_key="YOUR_API_KEY")
# Fetch retail sales
retail = fetch_series(client, "timeseries/eits/retail:MRTSSM44X72USS", Date(2020, 1, 1), Date(2023, 12, 31))
```
"""

using HTTP
using JSON3
using Dates
using DataFrames

struct CensusClient
    base_url::String
    api_key::Union{String, Nothing}
    rate_limiter::RateLimiter
    cache::SQLiteCache
    retry_config::RetryConfig

    function CensusClient(;
        api_key::Union{String, Nothing}=get(ENV, "CENSUS_API_KEY", nothing),
        cache_ttl::Int=86400
    )
        if api_key === nothing
            @warn "Census API key not provided. Daily limit is 500 requests. Get a key at https://api.census.gov/data/key_signup.html"
        end

        base_url = "https://api.census.gov/data"
        # Rate limiting: Spread requests to stay under daily limit
        # 500/day = ~0.35/minute, use 20/minute to be safe
        rate_limiter = RateLimiter(api_key !== nothing ? 80 : 20)
        cache = SQLiteCache(default_ttl=cache_ttl)
        retry_config = RetryConfig()

        new(base_url, api_key, rate_limiter, cache, retry_config)
    end
end

"""
Parse Census series ID in format: DATASET/SUBDATASET:VARIABLE
Examples:
- "timeseries/eits/retail:MRTSSM44X72USS" - Retail sales (monthly)
- "acs/acs5:B01001_001E" - ACS 5-year estimates, total population
- "pep/population:POP" - Population estimates
"""
function parse_series_id(series_id::String)::Dict{String, String}
    parts = split(series_id, ":")
    if length(parts) != 2
        throw(ArgumentError("Invalid Census series ID format. Expected DATASET:VARIABLE"))
    end

    dataset_path = parts[1]
    variable = parts[2]

    return Dict("dataset" => dataset_path, "variable" => variable)
end

"""
Fetch data series from Census API

Arguments:
- client: CensusClient instance
- series_id: Series identifier (format: DATASET:VARIABLE)
- start_date: Start date for data
- end_date: End date for data

Returns DataFrame with columns: date, value, series_id
"""
function fetch_series(client::CensusClient, series_id::String, start_date::Date, end_date::Date)::DataFrame
    # Check cache first
    key = cache_key("census", series_id, start_date, end_date)
    cached = get_cached(client.cache, key)
    if cached !== nothing
        @info "Returning cached Census data for series: $series_id"
        return parse_census_response(cached, series_id)
    end

    # Rate limit
    wait_if_needed(client.rate_limiter)

    # Parse series ID
    parsed = parse_series_id(series_id)
    dataset = parsed["dataset"]
    variable = parsed["variable"]

    # Build URL
    url = "$(client.base_url)/$dataset"

    # Build query parameters
    params = Dict(
        "get" => variable,
        "time" => "from $(Dates.year(start_date)) to $(Dates.year(end_date))"
    )

    if client.api_key !== nothing
        params["key"] = client.api_key
    end

    # For geographic data, need to specify location
    # Default to US total
    if contains(dataset, "acs") || contains(dataset, "pep")
        params["for"] = "us:*"
    end

    # Make request with retry logic
    fetch_func = () -> begin
        response = HTTP.get(url, query=params)
        if response.status != 200
            throw(HTTPError(response.status, "Census API returned status $(response.status)"))
        end
        return String(response.body)
    end

    try
        json_str = with_retry(fetch_func, client.retry_config)

        # Cache the result
        set_cached(client.cache, key, json_str)

        # Parse and return
        return parse_census_response(json_str, series_id)
    catch e
        @warn "Census API request failed: $e"
        # Try to return cached data if available
        cached = get_cached(client.cache, key, ignore_ttl=true)
        if cached !== nothing
            @info "Returning expired cache data due to API failure"
            return parse_census_response(cached, series_id)
        end
        rethrow(e)
    end
end

"""
Parse Census JSON response into DataFrame

Census API returns data as JSON array:
[
  ["VARIABLE", "time", "us"],
  ["value1", "2020", "1"],
  ["value2", "2021", "1"]
]
"""
function parse_census_response(json_str::String, series_id::String)::DataFrame
    data = JSON3.read(json_str)

    if length(data) < 2
        throw(ArgumentError("Invalid Census API response: no data"))
    end

    # First row is headers
    headers = data[1]

    # Rest are observations
    dates = Date[]
    values = Float64[]

    for i in 2:length(data)
        row = data[i]

        # Parse time/date (can be year, month, or specific date)
        time_str = row[2]

        # Parse date based on format
        date = if length(time_str) == 4
            # Year only: "2023"
            Date(parse(Int, time_str), 1, 1)
        elseif length(time_str) == 7 && occursin("-", time_str)
            # Year-Month: "2023-01"
            parts = split(time_str, "-")
            Date(parse(Int, parts[1]), parse(Int, parts[2]), 1)
        else
            # Full date: "2023-01-15"
            Date(time_str)
        end

        # Parse value
        value_str = row[1]
        value = try
            parse(Float64, value_str)
        catch
            NaN
        end

        push!(dates, date)
        push!(values, value)
    end

    return DataFrame(
        date = dates,
        value = values,
        series_id = fill(series_id, length(dates))
    )
end

"""
Search for Census data series

Returns common economic indicators that match the query
"""
function search_series(client::CensusClient, query::String; limit::Int=100)::Vector{Dict}
    # Curated list of common Census economic indicators
    common_series = [
        Dict(
            "id" => "timeseries/eits/retail:MRTSSM44X72USS",
            "title" => "Retail Sales - Total (Monthly)",
            "dataset" => "Economic Indicators",
            "frequency" => "Monthly",
            "units" => "Millions of Dollars"
        ),
        Dict(
            "id" => "timeseries/eits/adv:PRPOP",
            "title" => "U.S. Resident Population",
            "dataset" => "Economic Indicators",
            "frequency" => "Monthly",
            "units" => "Thousands"
        ),
        Dict(
            "id" => "timeseries/eits/housing:HOUST",
            "title" => "Housing Starts - Total",
            "dataset" => "Economic Indicators",
            "frequency" => "Monthly",
            "units" => "Thousands of Units"
        ),
        Dict(
            "id" => "timeseries/eits/mwts:MWTIMVA",
            "title" => "Manufacturers' Shipments - Total",
            "dataset" => "Economic Indicators",
            "frequency" => "Monthly",
            "units" => "Millions of Dollars"
        ),
        Dict(
            "id" => "acs/acs5:B01001_001E",
            "title" => "Total Population (ACS 5-Year Estimates)",
            "dataset" => "American Community Survey",
            "frequency" => "Annual",
            "units" => "Count"
        ),
        Dict(
            "id" => "acs/acs5:B19013_001E",
            "title" => "Median Household Income (ACS 5-Year)",
            "dataset" => "American Community Survey",
            "frequency" => "Annual",
            "units" => "Dollars"
        ),
        Dict(
            "id" => "pep/population:POP",
            "title" => "Population Estimates",
            "dataset" => "Population Estimates Program",
            "frequency" => "Annual",
            "units" => "Count"
        ),
    ]

    # Filter by query
    query_lower = lowercase(query)
    filtered = filter(s -> occursin(query_lower, lowercase(s["title"])) ||
                           occursin(query_lower, lowercase(s["dataset"])) ||
                           occursin(query_lower, lowercase(s["id"])),
                      common_series)

    return first(filtered, limit)
end

"""
Get available Census datasets
"""
function get_datasets(client::CensusClient)::Vector{String}
    return [
        "timeseries/eits/retail",
        "timeseries/eits/housing",
        "timeseries/eits/mwts",
        "acs/acs1",
        "acs/acs5",
        "pep/population",
        "trade/timeseries",
        "cbp"
    ]
end
