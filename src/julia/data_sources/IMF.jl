"""
IMF (International Monetary Fund) Data Client

Provides access to IMF economic data through the SDMX-JSON API.

API Documentation: https://datahelp.imf.org/knowledgebase/articles/667681-using-json-restful-web-service

Common Databases:
- IFS: International Financial Statistics
- DOT: Direction of Trade Statistics
- BOP: Balance of Payments
- GFSR: Global Financial Stability Report

Rate Limit: 60 requests/minute
"""

using HTTP
using JSON3
using Dates

"""
    IMFClient

Client for fetching data from IMF SDMX-JSON API.

# Fields
- `base_url::String`: IMF API base URL
- `rate_limiter::RateLimiter`: Rate limiter (60/min)
- `cache::SQLiteCache`: Persistent cache
- `retry_config::RetryConfig`: Retry configuration
"""
struct IMFClient
    base_url::String
    rate_limiter::RateLimiter
    cache::SQLiteCache
    retry_config::RetryConfig

    function IMFClient(;
        cache_ttl::Int=86400
    )
        base_url = "http://dataservices.imf.org/REST/SDMX_JSON.svc"

        # IMF allows 60 requests per minute
        rate_limiter = RateLimiter(60)

        cache = SQLiteCache(default_ttl=cache_ttl)
        retry_config = RetryConfig()

        new(base_url, rate_limiter, cache, retry_config)
    end
end

"""
    fetch_series(client::IMFClient, database::String, indicator::String, frequency::String,
                 area::String, start_date::Date, end_date::Date)::DataFrame

Fetch economic time series data from IMF.

# Arguments
- `client::IMFClient`: IMF client instance
- `database::String`: Database ID (e.g., "IFS" for International Financial Statistics)
- `indicator::String`: Indicator code (e.g., "NGDP_R_SA_XDC" for Real GDP)
- `frequency::String`: Data frequency ("A"=Annual, "Q"=Quarterly, "M"=Monthly)
- `area::String`: Country/area code (e.g., "US" for United States)
- `start_date::Date`: Start date for data
- `end_date::Date`: End date for data

# Returns
- `DataFrame`: Time series data with columns [:date, :value]

# Example
```julia
client = IMFClient()
# Fetch US Real GDP (quarterly)
data = fetch_series(client, "IFS", "NGDP_R_SA_XDC", "Q", "US", Date(2020, 1, 1), Date(2023, 12, 31))
```
"""
function fetch_series(client::IMFClient, database::String, indicator::String, frequency::String,
                      area::String, start_date::Date, end_date::Date)::DataFrame
    # Check cache first
    key = cache_key("imf", database, indicator, frequency, area, start_date, end_date)
    cached = get_cached(client.cache, key)

    if cached !== nothing
        @debug "IMF: Cache hit" database indicator area
        return JSON3.read(cached, DataFrame)
    end

    @debug "IMF: Cache miss, fetching from API" database indicator area

    # Rate limit
    if !wait_if_needed(client.rate_limiter)
        @warn "IMF: Rate limit wait timeout, attempting cache fallback"
        throw(ErrorException("Rate limit timeout"))
    end

    # Build request
    function fetch()
        # Format: CompactData/{database}/{frequency}.{area}.{indicator}?startPeriod={start}&endPeriod={end}
        start_period = Dates.format(start_date, "yyyy-mm-dd")
        end_period = Dates.format(end_date, "yyyy-mm-dd")

        # Construct dimension string
        dimension = "$frequency.$area.$indicator"

        url = "$(client.base_url)/CompactData/$database/$dimension"

        @debug "IMF: Making API request" url database indicator

        response = HTTP.get(url, query=Dict(
            "startPeriod" => start_period,
            "endPeriod" => end_period
        ))

        if response.status != 200
            throw(HTTP.Exceptions.StatusError(response.status, response))
        end

        return response.body
    end

    # Execute with retry and cache fallback
    body, from_cache = with_retry_and_cache(fetch, client.cache, key, client.retry_config)

    if !from_cache
        # Parse fresh response
        data = JSON3.read(body)

        # Extract observations from SDMX-JSON structure
        # The structure varies, but typically: CompactData.DataSet.Series.Obs
        observations = []

        try
            dataset = data.CompactData.DataSet

            # Handle both single series and array of series
            series_data = if haskey(dataset, :Series)
                series = dataset.Series
                # Series can be a single object or an array
                isa(series, AbstractVector) ? series : [series]
            else
                []
            end

            for series in series_data
                if haskey(series, :Obs)
                    obs_data = series.Obs
                    obs_array = isa(obs_data, AbstractVector) ? obs_data : [obs_data]
                    append!(observations, obs_array)
                end
            end
        catch e
            @warn "IMF: Error parsing SDMX-JSON response" error=e
            throw(ErrorException("Failed to parse IMF response: $(e)"))
        end

        # Convert to DataFrame
        if isempty(observations)
            @warn "IMF: No observations found in response" database indicator area
            df = DataFrame(date=Date[], value=Union{Float64, Missing}[])
        else
            dates = Date[]
            values = Union{Float64, Missing}[]

            for obs in observations
                # Parse time period
                time_period = get(obs, Symbol("@TIME_PERIOD"), nothing)
                if time_period === nothing
                    continue
                end

                # Parse value
                obs_value = get(obs, Symbol("@OBS_VALUE"), nothing)
                if obs_value === nothing
                    push!(dates, parse_imf_date(time_period, frequency))
                    push!(values, missing)
                else
                    push!(dates, parse_imf_date(time_period, frequency))
                    push!(values, parse(Float64, obs_value))
                end
            end

            df = DataFrame(date=dates, value=values)
        end

        # Cache the result
        set_cached(
            client.cache,
            key,
            JSON3.write(df),
            metadata=Dict(
                "source" => "imf",
                "database" => database,
                "indicator" => indicator,
                "area" => area
            )
        )

        return df
    else
        # From cache after retry failure
        return body
    end
end

"""
    parse_imf_date(time_period::String, frequency::String)::Date

Parse IMF time period string to Date.

# Arguments
- `time_period::String`: IMF time period (e.g., "2020-Q1", "2020-01", "2020")
- `frequency::String`: Frequency indicator ("A", "Q", "M")

# Returns
- `Date`: Parsed date
"""
function parse_imf_date(time_period::String, frequency::String)::Date
    if frequency == "A"
        # Annual: "2020"
        year = parse(Int, time_period)
        return Date(year, 1, 1)
    elseif frequency == "Q"
        # Quarterly: "2020-Q1" or "2020Q1"
        parts = split(replace(time_period, "Q" => "-Q"), "-")
        year = parse(Int, parts[1])
        quarter = parse(Int, replace(parts[2], "Q" => ""))
        month = (quarter - 1) * 3 + 1
        return Date(year, month, 1)
    elseif frequency == "M"
        # Monthly: "2020-01" or "2020M01"
        clean = replace(time_period, "M" => "-")
        parts = split(clean, "-")
        year = parse(Int, parts[1])
        month = parse(Int, parts[2])
        return Date(year, month, 1)
    else
        # Try to parse as ISO date
        try
            return Date(time_period)
        catch
            @warn "IMF: Unknown frequency, defaulting to year" time_period frequency
            year = parse(Int, split(time_period, "-")[1])
            return Date(year, 1, 1)
        end
    end
end

"""
    search_series(client::IMFClient, database::String, query::String; limit::Int=100)::Vector{Dict}

Search for IMF series by keyword in a specific database.

Note: IMF API has limited search capabilities. This function searches through available
dimensions and indicators in the specified database.

# Arguments
- `client::IMFClient`: IMF client instance
- `database::String`: Database ID (e.g., "IFS", "DOT")
- `query::String`: Search query (searches in indicator names/descriptions)
- `limit::Int`: Maximum results to return (default: 100)

# Returns
- `Vector{Dict}`: Search results with series metadata

# Example
```julia
client = IMFClient()
results = search_series(client, "IFS", "GDP")
```
"""
function search_series(client::IMFClient, database::String, query::String; limit::Int=100)::Vector{Dict}
    # Check cache
    key = cache_key("imf", "search:$database:$query")
    cached = get_cached(client.cache, key)

    if cached !== nothing
        @debug "IMF: Search cache hit" database query
        return JSON3.read(cached)
    end

    # Rate limit
    if !wait_if_needed(client.rate_limiter)
        throw(ErrorException("Rate limit timeout"))
    end

    # Get dataflow structure for the database
    url = "$(client.base_url)/Dataflow/$database"

    @debug "IMF: Fetching dataflow structure" database

    response = HTTP.get(url)

    if response.status != 200
        throw(HTTP.Exceptions.StatusError(response.status, response))
    end

    data = JSON3.read(response.body)

    # Extract available indicators/dimensions
    results = []

    try
        # Parse SDMX structure (structure varies by database)
        structure = data.Structure

        if haskey(structure, :Dataflows)
            dataflows = structure.Dataflows
            dataflow_arr = haskey(dataflows, :Dataflow) ? dataflows.Dataflow : []
            dataflow_arr = isa(dataflow_arr, AbstractVector) ? dataflow_arr : [dataflow_arr]

            for dataflow in dataflow_arr
                name = get(dataflow, :Name, Dict())
                name_text = isa(name, AbstractVector) ? first(name) : name
                description = get(name_text, Symbol("#text"), "")

                id = get(dataflow, Symbol("@id"), "")

                # Filter by query (case-insensitive)
                if isempty(query) || occursin(lowercase(query), lowercase(description)) || occursin(lowercase(query), lowercase(id))
                    push!(results, Dict(
                        "id" => id,
                        "title" => description,
                        "database" => database
                    ))

                    if length(results) >= limit
                        break
                    end
                end
            end
        end
    catch e
        @warn "IMF: Error parsing dataflow structure" error=e database
    end

    # Cache results
    set_cached(
        client.cache,
        key,
        JSON3.write(results),
        ttl=3600,  # Cache searches for 1 hour
        metadata=Dict("source" => "imf", "type" => "search", "database" => database)
    )

    return results
end

"""
    get_database_structure(client::IMFClient, database::String)::Dict

Get the complete structure (dimensions, codes) for an IMF database.

# Arguments
- `client::IMFClient`: IMF client instance
- `database::String`: Database ID (e.g., "IFS", "DOT")

# Returns
- `Dict`: Database structure metadata

# Example
```julia
client = IMFClient()
structure = get_database_structure(client, "IFS")
```
"""
function get_database_structure(client::IMFClient, database::String)::Dict
    # Rate limit
    if !wait_if_needed(client.rate_limiter)
        throw(ErrorException("Rate limit timeout"))
    end

    url = "$(client.base_url)/DataStructure/$database"

    @debug "IMF: Fetching database structure" database

    response = HTTP.get(url)

    if response.status != 200
        throw(HTTP.Exceptions.StatusError(response.status, response))
    end

    data = JSON3.read(response.body)

    # Extract dimensions and code lists
    structure_info = Dict(
        "database" => database,
        "dimensions" => [],
        "codelists" => Dict()
    )

    try
        if haskey(data, :Structure)
            struct_data = data.Structure

            # Extract dimensions
            if haskey(struct_data, :KeyFamilies) && haskey(struct_data.KeyFamilies, :KeyFamily)
                key_family = struct_data.KeyFamilies.KeyFamily
                if haskey(key_family, :Components) && haskey(key_family.Components, :Dimension)
                    dimensions = key_family.Components.Dimension
                    dim_array = isa(dimensions, AbstractVector) ? dimensions : [dimensions]

                    for dim in dim_array
                        dim_info = Dict(
                            "id" => get(dim, Symbol("@conceptRef"), ""),
                            "codelist" => get(dim, Symbol("@codelist"), "")
                        )
                        push!(structure_info["dimensions"], dim_info)
                    end
                end
            end

            # Extract code lists
            if haskey(struct_data, :CodeLists) && haskey(struct_data.CodeLists, :CodeList)
                codelists = struct_data.CodeLists.CodeList
                codelist_array = isa(codelists, AbstractVector) ? codelists : [codelists]

                for codelist in codelist_array
                    codelist_id = get(codelist, Symbol("@id"), "")
                    codes = []

                    if haskey(codelist, :Code)
                        code_items = codelist.Code
                        code_array = isa(code_items, AbstractVector) ? code_items : [code_items]

                        for code in code_array
                            code_value = get(code, Symbol("@value"), "")
                            description = get(code, :Description, Dict())
                            desc_text = isa(description, AbstractVector) ? first(description) : description
                            desc_value = get(desc_text, Symbol("#text"), "")

                            push!(codes, Dict(
                                "value" => code_value,
                                "description" => desc_value
                            ))
                        end
                    end

                    structure_info["codelists"][codelist_id] = codes
                end
            end
        end
    catch e
        @warn "IMF: Error parsing database structure" error=e database
    end

    return structure_info
end
