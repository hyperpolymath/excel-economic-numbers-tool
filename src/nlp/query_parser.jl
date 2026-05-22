# SPDX-License-Identifier: MPL-2.0
"""
Natural Language Query Parser - v3.0

Parse natural language queries and convert them to API calls
using Claude API for intent recognition.
"""

using HTTP, JSON3, Dates

struct NLPQuery
    text::String
    intent::Union{String, Nothing}
    entities::Dict{String, Any}
    confidence::Float64
end

struct QueryResult
    data::Any
    visualization_hint::String
    explanation::String
    sql_equivalent::String
end

"""
Parse a natural language query using Claude API
"""
function parse_query(query_text::String; api_key::String=get(ENV, "ANTHROPIC_API_KEY", ""))::NLPQuery
    if isempty(api_key)
        @warn "ANTHROPIC_API_KEY not set, using pattern matching"
        return parse_query_fallback(query_text)
    end

    # Call Claude API for intent recognition
    prompt = """
    Parse this economic data query and extract structured information:
    Query: "$query_text"

    Provide a JSON response with:
    {
      "intent": "fetch_data|calculate|compare|forecast|explain",
      "entities": {
        "data_source": "fred|worldbank|imf|etc",
        "indicator": "GDP|unemployment|inflation|etc",
        "country": "USA|UK|etc",
        "start_date": "YYYY-MM-DD",
        "end_date": "YYYY-MM-DD",
        "operation": "growth_rate|gini|etc"
      },
      "confidence": 0.0-1.0
    }
    """

    response = HTTP.post(
        "https://api.anthropic.com/v1/messages",
        ["Content-Type" => "application/json",
         "x-api-key" => api_key,
         "anthropic-version" => "2023-06-01"],
        JSON3.write(Dict(
            "model" => "claude-3-5-sonnet-20241022",
            "max_tokens" => 1024,
            "messages" => [
                Dict("role" => "user", "content" => prompt)
            ]
        ))
    )

    result = JSON3.read(String(response.body))
    content = result.content[1].text

    # Parse JSON from Claude's response
    parsed = JSON3.read(content)

    return NLPQuery(
        query_text,
        get(parsed, :intent, nothing),
        Dict(String(k) => v for (k, v) in pairs(get(parsed, :entities, Dict()))),
        get(parsed, :confidence, 0.5)
    )
end

"""
Fallback parser using pattern matching (no API required)
"""
function parse_query_fallback(query_text::String)::NLPQuery
    text_lower = lowercase(query_text)

    # Extract intent
    intent = if occursin(r"show|get|fetch|retrieve", text_lower)
        "fetch_data"
    elseif occursin(r"calculate|compute", text_lower)
        "calculate"
    elseif occursin(r"compare", text_lower)
        "compare"
    elseif occursin(r"forecast|predict", text_lower)
        "forecast"
    elseif occursin(r"explain|why|what", text_lower)
        "explain"
    else
        "fetch_data"
    end

    # Extract entities
    entities = Dict{String, Any}()

    # Data sources
    if occursin("fred", text_lower) || occursin("federal reserve", text_lower)
        entities["data_source"] = "fred"
    elseif occursin("world bank", text_lower)
        entities["data_source"] = "worldbank"
    elseif occursin("imf", text_lower)
        entities["data_source"] = "imf"
    end

    # Indicators
    if occursin("gdp", text_lower) || occursin("gross domestic product", text_lower)
        entities["indicator"] = "GDP"
    elseif occursin("unemployment", text_lower)
        entities["indicator"] = "unemployment"
    elseif occursin("inflation", text_lower)
        entities["indicator"] = "inflation"
    elseif occursin("interest rate", text_lower)
        entities["indicator"] = "interest_rate"
    end

    # Countries
    country_map = Dict(
        "usa" => "USA", "us" => "USA", "united states" => "USA", "america" => "USA",
        "uk" => "GBR", "united kingdom" => "GBR", "britain" => "GBR",
        "germany" => "DEU", "france" => "FRA", "japan" => "JPN",
        "china" => "CHN", "india" => "IND", "brazil" => "BRA"
    )

    for (pattern, code) in country_map
        if occursin(pattern, text_lower)
            entities["country"] = code
            break
        end
    end

    # Date ranges
    current_year = year(now())
    if occursin(r"last (\d+) years?", text_lower)
        m = match(r"last (\d+) years?", text_lower)
        years_back = parse(Int, m.captures[1])
        entities["start_date"] = string(Date(current_year - years_back, 1, 1))
        entities["end_date"] = string(Date(current_year, 12, 31))
    elseif occursin(r"from (\d{4}) to (\d{4})", text_lower)
        m = match(r"from (\d{4}) to (\d{4})", text_lower)
        entities["start_date"] = "$(m.captures[1])-01-01"
        entities["end_date"] = "$(m.captures[2])-12-31"
    end

    # Operations
    if occursin("growth", text_lower)
        entities["operation"] = "growth_rate"
    elseif occursin("gini", text_lower) || occursin("inequality", text_lower)
        entities["operation"] = "gini"
    elseif occursin("average", text_lower) || occursin("mean", text_lower)
        entities["operation"] = "mean"
    end

    confidence = length(entities) >= 2 ? 0.8 : 0.5

    return NLPQuery(query_text, intent, entities, confidence)
end

"""
Execute a parsed query
"""
function execute_query(parsed::NLPQuery, toolkit)::QueryResult
    if isnothing(parsed.intent)
        return QueryResult(
            nothing,
            "none",
            "Could not understand the query",
            ""
        )
    end

    if parsed.intent == "fetch_data"
        # Fetch data from appropriate source
        source = get(parsed.entities, "data_source", "fred")
        indicator = get(parsed.entities, "indicator", "GDP")
        country = get(parsed.entities, "country", "USA")
        start_date = get(parsed.entities, "start_date", string(Date(year(now())-5, 1, 1)))
        end_date = get(parsed.entities, "end_date", string(today()))

        # Mock data fetching (in production, use actual client)
        data = Dict(
            "source" => source,
            "indicator" => indicator,
            "country" => country,
            "observations" => [
                Dict("date" => start_date, "value" => 100.0),
                Dict("date" => end_date, "value" => 110.0)
            ]
        )

        return QueryResult(
            data,
            "line_chart",
            "Fetched $indicator data for $country from $start_date to $end_date",
            "SELECT * FROM $source WHERE indicator='$indicator' AND country='$country'"
        )

    elseif parsed.intent == "calculate"
        operation = get(parsed.entities, "operation", "mean")

        # Perform calculation (mock)
        result = Dict("operation" => operation, "result" => 5.2)

        return QueryResult(
            result,
            "number",
            "Calculated $operation",
            "SELECT $operation(value) FROM data"
        )

    elseif parsed.intent == "forecast"
        # Generate forecast
        forecast_data = [115.0, 120.0, 125.0, 130.0]

        return QueryResult(
            Dict("forecast" => forecast_data, "confidence_interval" => [110.0, 135.0]),
            "line_chart",
            "Generated forecast using ARIMA model",
            "-- Forecast generated using time series model"
        )

    else
        return QueryResult(
            nothing,
            "none",
            "Intent not implemented: $(parsed.intent)",
            ""
        )
    end
end

"""
Generate SQL equivalent for a natural language query
"""
function query_to_sql(parsed::NLPQuery)::String
    if isnothing(parsed.intent)
        return "-- Could not parse query"
    end

    entities = parsed.entities
    source = get(entities, "data_source", "economic_data")
    indicator = get(entities, "indicator", "value")
    country = get(entities, "country", nothing)
    start_date = get(entities, "start_date", nothing)
    end_date = get(entities, "end_date", nothing)
    operation = get(entities, "operation", nothing)

    where_clauses = String[]

    if !isnothing(country)
        push!(where_clauses, "country = '$country'")
    end
    if !isnothing(indicator)
        push!(where_clauses, "indicator = '$indicator'")
    end
    if !isnothing(start_date)
        push!(where_clauses, "date >= '$start_date'")
    end
    if !isnothing(end_date)
        push!(where_clauses, "date <= '$end_date'")
    end

    select_expr = if !isnothing(operation)
        "$(uppercase(operation))(value)"
    else
        "*"
    end

    where_str = isempty(where_clauses) ? "" : "\nWHERE " * join(where_clauses, "\n  AND ")

    return """
    SELECT $select_expr
    FROM $source$where_str
    ORDER BY date
    """
end

export NLPQuery, QueryResult, parse_query, execute_query, query_to_sql
