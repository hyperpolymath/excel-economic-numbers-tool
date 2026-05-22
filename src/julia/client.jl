# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2024-2026 Hyperpolymath Contributors

"""
    EconomicClient

Main client for interacting with the Economic Toolkit REST API.

# Fields
- `api_url::String`: Base URL for the REST API (default: "http://localhost:8080")
- `api_key::Union{String, Nothing}`: Optional API key for authentication
- `headers::Dict{String, String}`: HTTP headers for requests

# Examples
```julia
client = EconomicClient()
client = EconomicClient(api_url="https://api.example.com", api_key="my-key")
```
"""
mutable struct EconomicClient
    api_url::String
    api_key::Union{String, Nothing}
    headers::Dict{String, String}

    function EconomicClient(;
        api_url::String = "http://localhost:8080",
        api_key::Union{String, Nothing} = nothing,
    )
        url = rstrip(api_url, '/')
        headers = Dict{String, String}("Content-Type" => "application/json")
        if api_key !== nothing
            headers["Authorization"] = "Bearer $api_key"
        end
        new(url, api_key, headers)
    end
end

"""
    fetch_series(client, source, series_id; start_date=nothing, end_date=nothing)

Fetch economic data series from the specified source.

# Arguments
- `client::EconomicClient`: The API client
- `source::String`: Data source name (fred, worldbank, imf, etc.)
- `series_id::String`: Series identifier
- `start_date::Union{Date, Nothing}`: Optional start date
- `end_date::Union{Date, Nothing}`: Optional end date

# Returns
A `Dict` with series data and metadata.
"""
function fetch_series(
    client::EconomicClient,
    source::String,
    series_id::String;
    start_date::Union{Date, Nothing} = nothing,
    end_date::Union{Date, Nothing} = nothing,
)::Dict
    params = Dict{String, String}()
    if start_date !== nothing
        params["start"] = string(start_date)
    end
    if end_date !== nothing
        params["end"] = string(end_date)
    end

    url = "$(client.api_url)/api/v1/sources/$source/series/$series_id"
    if !isempty(params)
        query_string = join(["$k=$v" for (k, v) in params], "&")
        url = "$url?$query_string"
    end

    response = HTTP.get(url, client.headers)
    return JSON3.read(String(response.body), Dict)
end

"""
    search_series(client, source, query)

Search for economic data series.

# Arguments
- `client::EconomicClient`: The API client
- `source::String`: Data source name
- `query::String`: Search query string

# Returns
A `Vector` of matching series dictionaries.
"""
function search_series(
    client::EconomicClient,
    source::String,
    query::String,
)::Vector
    url = "$(client.api_url)/api/v1/sources/$source/search?q=$(HTTP.escapeuri(query))"
    response = HTTP.get(url, client.headers)
    return JSON3.read(String(response.body), Vector)
end

"""
    list_sources(client)

List all available data sources.

# Arguments
- `client::EconomicClient`: The API client

# Returns
A `Vector` of data source dictionaries with id, name, and status.
"""
function list_sources(client::EconomicClient)::Vector
    url = "$(client.api_url)/api/v1/sources"
    response = HTTP.get(url, client.headers)
    return JSON3.read(String(response.body), Vector)
end

"""
    health(client)

Check API health status.

# Arguments
- `client::EconomicClient`: The API client

# Returns
A `Dict` with health status information.
"""
function health(client::EconomicClient)::Dict
    url = "$(client.api_url)/health"
    response = HTTP.get(url, client.headers)
    return JSON3.read(String(response.body), Dict)
end
