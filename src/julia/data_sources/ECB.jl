"""
ECB (European Central Bank) Data Client

Provides access to economic and financial data from the European Central Bank via SDMX API.

API Documentation: https://data.ecb.europa.eu/help/api/overview

Common Data Flows:
- EXR: Exchange Rates
- ICP: Inflation (HICP - Harmonised Index of Consumer Prices)
- FM: Financial Markets
- RTD: Retail Interest Rates
- BSI: Balance Sheet Items

Rate Limit: 60 requests/minute
No API key required
"""

using HTTP
using JSON3
using Dates
using LightXML

"""
    ECBClient

Client for fetching data from ECB SDMX API.

# Fields
- `base_url::String`: ECB API base URL
- `rate_limiter::RateLimiter`: Rate limiter (60/min)
- `cache::SQLiteCache`: Persistent cache
- `retry_config::RetryConfig`: Retry configuration
"""
struct ECBClient
    base_url::String
    rate_limiter::RateLimiter
    cache::SQLiteCache
    retry_config::RetryConfig

    function ECBClient(; cache_ttl::Int=86400)
        base_url = "https://data-api.ecb.europa.eu/service"

        # ECB rate limit is 60 requests per minute
        rate_limiter = RateLimiter(60)

        cache = SQLiteCache(default_ttl=cache_ttl)
        retry_config = RetryConfig()

        new(base_url, rate_limiter, cache, retry_config)
    end
end

"""
    parse_sdmx_data(xml_content::String)::DataFrame

Parse SDMX-ML format to DataFrame.

# Arguments
- `xml_content::String`: XML content in SDMX format

# Returns
- `DataFrame`: Time series data with columns [:date, :value]
"""
function parse_sdmx_data(xml_content::String)::DataFrame
    doc = parse_string(xml_content)
    root = LightXML.root(doc)

    dates = Date[]
    values = Union{Float64, Missing}[]

    # Navigate SDMX structure: DataSet -> Series -> Obs
    # SDMX namespaces can vary, so we search for elements
    for series in get_elements_by_tagname(root, "Series")
        for obs in get_elements_by_tagname(series, "Obs")
            # Get observation date
            date_elem = find_element(obs, "ObsDimension")
            if date_elem !== nothing
                date_str = attribute(date_elem, "value")

                # Parse date - ECB uses various formats (YYYY-MM-DD, YYYY-MM, YYYY-Www, etc.)
                date_val = try
                    if occursin("W", date_str)
                        # Weekly format: YYYY-Www
                        year_week = split(date_str, "-W")
                        year = parse(Int, year_week[1])
                        week = parse(Int, year_week[2])
                        Date(year, 1, 1) + Week(week - 1)
                    elseif length(date_str) == 7
                        # Monthly format: YYYY-MM
                        Date(date_str * "-01")
                    elseif length(date_str) == 4
                        # Annual format: YYYY
                        Date(date_str * "-01-01")
                    else
                        # Daily format: YYYY-MM-DD
                        Date(date_str)
                    end
                catch e
                    @warn "Failed to parse date" date_str exception=e
                    continue
                end

                # Get observation value
                value_elem = find_element(obs, "ObsValue")
                if value_elem !== nothing
                    value_str = attribute(value_elem, "value")
                    value_val = try
                        parse(Float64, value_str)
                    catch
                        missing
                    end

                    push!(dates, date_val)
                    push!(values, value_val)
                end
            end
        end
    end

    free(doc)

    # Sort by date
    perm = sortperm(dates)

    return DataFrame(date=dates[perm], value=values[perm])
end

"""
    fetch_series(client::ECBClient, flow::String, key::String, start_date::Date, end_date::Date)::DataFrame

Fetch economic time series data from ECB.

# Arguments
- `client::ECBClient`: ECB client instance
- `flow::String`: Data flow identifier (e.g., "EXR", "ICP", "FM")
- `key::String`: Series key (e.g., "D.USD.EUR.SP00.A" for daily USD/EUR exchange rate)
- `start_date::Date`: Start date for data
- `end_date::Date`: End date for data

# Returns
- `DataFrame`: Time series data with columns [:date, :value]

# Example
```julia
client = ECBClient()
# Fetch daily USD/EUR exchange rate
data = fetch_series(client, "EXR", "D.USD.EUR.SP00.A", Date(2020, 1, 1), Date(2023, 12, 31))

# Fetch monthly HICP for euro area
data = fetch_series(client, "ICP", "M.U2.N.000000.4.ANR", Date(2020, 1, 1), Date(2023, 12, 31))
```
"""
function fetch_series(client::ECBClient, flow::String, key::String, start_date::Date, end_date::Date)::DataFrame
    # Check cache first
    cache_id = cache_key("ecb", flow, key, start_date, end_date)
    cached = get_cached(client.cache, cache_id)

    if cached !== nothing
        @debug "ECB: Cache hit" flow key
        return JSON3.read(cached, DataFrame)
    end

    @debug "ECB: Cache miss, fetching from API" flow key

    # Rate limit
    if !wait_if_needed(client.rate_limiter)
        @warn "ECB: Rate limit wait timeout, attempting cache fallback"
        throw(ErrorException("Rate limit timeout"))
    end

    # Build request
    function fetch()
        # ECB SDMX API format: /data/{flow}/{key}?startPeriod=YYYY-MM-DD&endPeriod=YYYY-MM-DD
        url = "$(client.base_url)/data/$(flow)/$(key)"

        params = Dict(
            "startPeriod" => Dates.format(start_date, "yyyy-mm-dd"),
            "endPeriod" => Dates.format(end_date, "yyyy-mm-dd"),
            "format" => "sdmx-ml"  # SDMX-ML XML format
        )

        @debug "ECB: Making API request" url flow key

        response = HTTP.get(url, query=params)

        if response.status != 200
            throw(HTTP.Exceptions.StatusError(response.status, response))
        end

        return response.body
    end

    # Execute with retry and cache fallback
    body, from_cache = with_retry_and_cache(fetch, client.cache, cache_id, client.retry_config)

    if !from_cache
        # Parse fresh response
        xml_content = String(body)
        df = parse_sdmx_data(xml_content)

        # Cache the result
        set_cached(
            client.cache,
            cache_id,
            JSON3.write(df),
            metadata=Dict("source" => "ecb", "flow" => flow, "key" => key)
        )

        return df
    else
        # From cache after retry failure
        return body
    end
end

"""
    search_series(client::ECBClient, flow::String, query::String; limit::Int=100)::Vector{Dict}

Search for ECB series within a specific data flow.

# Arguments
- `client::ECBClient`: ECB client instance
- `flow::String`: Data flow identifier (e.g., "EXR", "ICP", "FM")
- `query::String`: Search query (searches in series descriptions)
- `limit::Int`: Maximum results to return (default: 100)

# Returns
- `Vector{Dict}`: Search results with series metadata

# Example
```julia
client = ECBClient()
# Search for USD-related exchange rates
results = search_series(client, "EXR", "USD")

# Search for inflation indicators
results = search_series(client, "ICP", "inflation")
```
"""
function search_series(client::ECBClient, flow::String, query::String; limit::Int=100)::Vector{Dict}
    # Check cache
    cache_id = cache_key("ecb", "search:$flow:$query")
    cached = get_cached(client.cache, cache_id)

    if cached !== nothing
        @debug "ECB: Search cache hit" flow query
        return JSON3.read(cached)
    end

    # Rate limit
    if !wait_if_needed(client.rate_limiter)
        throw(ErrorException("Rate limit timeout"))
    end

    # Build request for dataflow structure
    # Note: ECB doesn't have a direct search API, so we fetch the dataflow structure
    # and filter based on the query
    url = "$(client.base_url)/datastructure/ECB/$(flow)"

    @debug "ECB: Fetching dataflow structure" url flow

    response = HTTP.get(url)

    if response.status != 200
        throw(HTTP.Exceptions.StatusError(response.status, response))
    end

    # Parse SDMX structure definition
    xml_content = String(response.body)
    doc = parse_string(xml_content)
    root_elem = LightXML.root(doc)

    results = Dict[]
    query_lower = lowercase(query)

    # Extract code lists and dimension information
    for codelist in get_elements_by_tagname(root_elem, "Codelist")
        codelist_id = attribute(codelist, "id", "")

        for code in get_elements_by_tagname(codelist, "Code")
            code_id = attribute(code, "id", "")

            # Get description
            desc_elem = find_element(code, "Name")
            description = desc_elem !== nothing ? content(desc_elem) : ""

            # Filter by query
            if occursin(query_lower, lowercase(description)) || occursin(query_lower, lowercase(code_id))
                push!(results, Dict(
                    "flow" => flow,
                    "code" => code_id,
                    "codelist" => codelist_id,
                    "description" => description
                ))

                if length(results) >= limit
                    break
                end
            end
        end

        if length(results) >= limit
            break
        end
    end

    free(doc)

    # Cache results
    set_cached(
        client.cache,
        cache_id,
        JSON3.write(results),
        ttl=3600,  # Cache searches for 1 hour
        metadata=Dict("source" => "ecb", "type" => "search", "flow" => flow)
    )

    return results
end

"""
    get_dataflows(client::ECBClient)::Vector{Dict}

Get list of available data flows from ECB.

# Arguments
- `client::ECBClient`: ECB client instance

# Returns
- `Vector{Dict}`: Available data flows with metadata

# Example
```julia
client = ECBClient()
flows = get_dataflows(client)
```
"""
function get_dataflows(client::ECBClient)::Vector{Dict}
    # Check cache
    cache_id = cache_key("ecb", "dataflows")
    cached = get_cached(client.cache, cache_id)

    if cached !== nothing
        @debug "ECB: Dataflows cache hit"
        return JSON3.read(cached)
    end

    # Rate limit
    if !wait_if_needed(client.rate_limiter)
        throw(ErrorException("Rate limit timeout"))
    end

    url = "$(client.base_url)/dataflow/ECB"

    response = HTTP.get(url)

    if response.status != 200
        throw(HTTP.Exceptions.StatusError(response.status, response))
    end

    xml_content = String(response.body)
    doc = parse_string(xml_content)
    root_elem = LightXML.root(doc)

    flows = Dict[]

    for dataflow in get_elements_by_tagname(root_elem, "Dataflow")
        flow_id = attribute(dataflow, "id", "")

        # Get name/description
        name_elem = find_element(dataflow, "Name")
        name = name_elem !== nothing ? content(name_elem) : ""

        push!(flows, Dict(
            "id" => flow_id,
            "name" => name
        ))
    end

    free(doc)

    # Cache results (cache for 24 hours as flows don't change often)
    set_cached(
        client.cache,
        cache_id,
        JSON3.write(flows),
        ttl=86400,
        metadata=Dict("source" => "ecb", "type" => "dataflows")
    )

    return flows
end

"""
    get_series_info(client::ECBClient, flow::String, key::String)::Dict

Get metadata for a specific ECB series.

# Arguments
- `client::ECBClient`: ECB client instance
- `flow::String`: Data flow identifier
- `key::String`: Series key

# Returns
- `Dict`: Series metadata

# Example
```julia
client = ECBClient()
info = get_series_info(client, "EXR", "D.USD.EUR.SP00.A")
```
"""
function get_series_info(client::ECBClient, flow::String, key::String)::Dict
    # Rate limit
    if !wait_if_needed(client.rate_limiter)
        throw(ErrorException("Rate limit timeout"))
    end

    # Fetch data structure for the flow
    url = "$(client.base_url)/datastructure/ECB/$(flow)"

    response = HTTP.get(url)

    if response.status != 200
        throw(HTTP.Exceptions.StatusError(response.status, response))
    end

    xml_content = String(response.body)
    doc = parse_string(xml_content)
    root_elem = LightXML.root(doc)

    # Parse key components (e.g., "D.USD.EUR.SP00.A" -> [D, USD, EUR, SP00, A])
    key_parts = split(key, ".")

    info = Dict(
        "flow" => flow,
        "key" => key,
        "dimensions" => Dict[]
    )

    # Extract dimension definitions
    dimension_idx = 1
    for dimension in get_elements_by_tagname(root_elem, "Dimension")
        if dimension_idx <= length(key_parts)
            dim_id = attribute(dimension, "id", "")

            name_elem = find_element(dimension, "Name")
            dim_name = name_elem !== nothing ? content(name_elem) : dim_id

            push!(info["dimensions"], Dict(
                "id" => dim_id,
                "name" => dim_name,
                "value" => key_parts[dimension_idx]
            ))

            dimension_idx += 1
        end
    end

    free(doc)

    return info
end
