# SPDX-License-Identifier: PMPL-1.0-or-later
"""
AI-Powered Insights Generator - v3.0

Automatically detect trends, anomalies, and generate insights
from economic data using Claude API.
"""

using Statistics, Dates, HTTP, JSON3

struct Insight
    type::String  # "trend", "anomaly", "pattern", "correlation", "forecast"
    severity::String  # "info", "warning", "critical"
    title::String
    description::String
    evidence::Dict{String, Any}
    confidence::Float64
    timestamp::DateTime
end

struct DataAnalysis
    insights::Vector{Insight}
    summary::String
    recommendations::Vector{String}
end

"""
Analyze time series data for trends
"""
function detect_trend(values::Vector{Float64})::Union{Insight, Nothing}
    if length(values) < 3
        return nothing
    end

    # Simple linear regression
    n = length(values)
    x = collect(1:n)
    x_mean = mean(x)
    y_mean = mean(values)

    numerator = sum((x .- x_mean) .* (values .- y_mean))
    denominator = sum((x .- x_mean).^2)
    slope = numerator / denominator

    # Determine trend direction and strength
    trend_type = if abs(slope) < 0.01 * y_mean
        "stable"
    elseif slope > 0
        "increasing"
    else
        "decreasing"
    end

    # Calculate R-squared
    predictions = (slope .* (x .- x_mean)) .+ y_mean
    ss_res = sum((values .- predictions).^2)
    ss_tot = sum((values .- y_mean).^2)
    r_squared = 1 - (ss_res / ss_tot)

    if abs(slope) < 0.01 * y_mean
        return nothing  # No significant trend
    end

    change_percent = (slope / y_mean) * 100

    return Insight(
        "trend",
        abs(change_percent) > 10 ? "warning" : "info",
        "$(uppercasefirst(trend_type)) Trend Detected",
        "The data shows a $(trend_type) trend with an average change of $(round(change_percent, digits=2))% per period. R² = $(round(r_squared, digits=3))",
        Dict(
            "slope" => slope,
            "r_squared" => r_squared,
            "change_percent" => change_percent,
            "trend_direction" => trend_type
        ),
        r_squared,
        now()
    )
end

"""
Detect anomalies using statistical methods
"""
function detect_anomalies(values::Vector{Float64}, dates::Vector{Date}=Date[])::Vector{Insight}
    if length(values) < 10
        return Insight[]
    end

    insights = Insight[]

    # Calculate statistics
    μ = mean(values)
    σ = std(values)

    # Z-score method
    z_scores = (values .- μ) ./ σ

    for (i, z) in enumerate(z_scores)
        if abs(z) > 3  # 3 standard deviations
            date_str = isempty(dates) ? "observation $i" : string(dates[i])
            severity = abs(z) > 4 ? "critical" : "warning"

            push!(insights, Insight(
                "anomaly",
                severity,
                "Anomaly Detected",
                "Value $(round(values[i], digits=2)) at $date_str is $(round(abs(z), digits=2)) standard deviations from the mean ($(round(μ, digits=2)))",
                Dict(
                    "value" => values[i],
                    "z_score" => z,
                    "mean" => μ,
                    "std_dev" => σ,
                    "index" => i
                ),
                min(abs(z) / 4, 1.0),
                now()
            ))
        end
    end

    return insights
end

"""
Detect patterns (seasonality, cycles)
"""
function detect_patterns(values::Vector{Float64})::Union{Insight, Nothing}
    if length(values) < 24  # Need at least 2 years of monthly data
        return nothing
    end

    # Simple autocorrelation for seasonality
    n = length(values)
    lags = [12, 4, 7]  # Check for yearly, quarterly, weekly patterns

    for lag in lags
        if lag >= n
            continue
        end

        # Calculate autocorrelation
        v1 = values[1:end-lag]
        v2 = values[lag+1:end]

        corr = cor(v1, v2)

        if corr > 0.7
            period_name = if lag == 12
                "annual"
            elseif lag == 4
                "quarterly"
            elseif lag == 7
                "weekly"
            else
                "$lag-period"
            end

            return Insight(
                "pattern",
                "info",
                "$(uppercasefirst(period_name)) Pattern Detected",
                "The data shows strong $period_name seasonality (correlation: $(round(corr, digits=3)))",
                Dict(
                    "pattern_type" => period_name,
                    "lag" => lag,
                    "correlation" => corr
                ),
                corr,
                now()
            )
        end
    end

    return nothing
end

"""
Generate comprehensive analysis using AI
"""
function generate_ai_insights(
    values::Vector{Float64},
    dates::Vector{Date}=Date[],
    indicator_name::String="Economic Indicator";
    api_key::String=get(ENV, "ANTHROPIC_API_KEY", "")
)::DataAnalysis

    insights = Insight[]

    # Statistical analysis
    trend_insight = detect_trend(values)
    if !isnothing(trend_insight)
        push!(insights, trend_insight)
    end

    anomaly_insights = detect_anomalies(values, dates)
    append!(insights, anomaly_insights)

    pattern_insight = detect_patterns(values)
    if !isnothing(pattern_insight)
        push!(insights, pattern_insight)
    end

    # Generate AI summary if API key available
    summary = ""
    recommendations = String[]

    if !isempty(api_key)
        stats_summary = """
        Indicator: $indicator_name
        Data points: $(length(values))
        Mean: $(round(mean(values), digits=2))
        Std Dev: $(round(std(values), digits=2))
        Min: $(round(minimum(values), digits=2))
        Max: $(round(maximum(values), digits=2))
        Insights found: $(length(insights))
        """

        prompt = """
        Analyze this economic indicator and provide:
        1. A brief summary (2-3 sentences)
        2. Three actionable recommendations

        Data:
        $stats_summary

        Detected insights:
        $(join([i.title * ": " * i.description for i in insights], "\n"))

        Respond in JSON format:
        {
          "summary": "...",
          "recommendations": ["...", "...", "..."]
        }
        """

        try
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
            parsed = JSON3.read(content)

            summary = get(parsed, :summary, "")
            recommendations = collect(get(parsed, :recommendations, String[]))
        catch e
            @warn "Failed to generate AI insights" exception=e
            summary = "Analysis complete with $(length(insights)) insights detected."
            recommendations = [
                "Review detected anomalies for data quality issues",
                "Monitor trend direction for strategic planning",
                "Consider seasonal adjustments if patterns detected"
            ]
        end
    else
        summary = "Statistical analysis complete with $(length(insights)) insights detected."
        recommendations = [
            "Review detected anomalies for data quality issues",
            "Monitor trend direction for strategic planning",
            "Consider seasonal adjustments if patterns detected"
        ]
    end

    return DataAnalysis(insights, summary, recommendations)
end

"""
Generate automated report
"""
function generate_report(analysis::DataAnalysis, indicator_name::String="Economic Indicator")::String
    report = """
    # $indicator_name Analysis Report

    Generated: $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))

    ## Summary

    $(analysis.summary)

    ## Key Insights ($(length(analysis.insights)))

    """

    # Sort insights by severity
    severity_order = Dict("critical" => 1, "warning" => 2, "info" => 3)
    sorted_insights = sort(analysis.insights, by=i -> get(severity_order, i.severity, 4))

    for insight in sorted_insights
        emoji = if insight.severity == "critical"
            "🔴"
        elseif insight.severity == "warning"
            "🟡"
        else
            "🔵"
        end

        report *= """
        ### $emoji $(insight.title)

        **Type:** $(insight.type) | **Confidence:** $(round(insight.confidence * 100, digits=1))%

        $(insight.description)

        """
    end

    report *= """
    ## Recommendations

    """

    for (i, rec) in enumerate(analysis.recommendations)
        report *= "$(i). $rec\n"
    end

    return report
end

export Insight, DataAnalysis, generate_ai_insights, generate_report, detect_trend, detect_anomalies, detect_patterns
