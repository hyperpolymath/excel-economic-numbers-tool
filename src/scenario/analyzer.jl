# SPDX-License-Identifier: MPL-2.0
"""
Scenario Analysis and Modeling - v4.0

Build and compare multiple economic scenarios with sensitivity analysis.
"""

using Statistics, Distributions

struct Scenario
    id::String
    name::String
    description::String
    assumptions::Dict{String, Float64}
    probability::Float64
end

struct ScenarioResult
    scenario::Scenario
    outcomes::Dict{String, Float64}
    metrics::Dict{String, Float64}
    timestamp::DateTime
end

struct SensitivityAnalysis
    parameter::String
    values::Vector{Float64}
    outcomes::Vector{Float64}
    elasticity::Float64
end

"""
Create a scenario with named assumptions
"""
function create_scenario(
    name::String,
    assumptions::Dict{String, Float64};
    description::String="",
    probability::Float64=1.0
)::Scenario

    id = string(hash(name * string(now())))

    return Scenario(id, name, description, assumptions, probability)
end

"""
Run scenario analysis with a model function
"""
function analyze_scenarios(
    scenarios::Vector{Scenario},
    model_func::Function
)::Vector{ScenarioResult}

    results = ScenarioResult[]

    for scenario in scenarios
        # Run model with scenario assumptions
        outcomes = model_func(scenario.assumptions)

        # Calculate metrics
        metrics = Dict{String, Float64}()

        if haskey(outcomes, "gdp") && haskey(outcomes, "baseline_gdp")
            metrics["gdp_change_pct"] = ((outcomes["gdp"] - outcomes["baseline_gdp"]) / outcomes["baseline_gdp"]) * 100
        end

        if haskey(outcomes, "employment") && haskey(outcomes, "baseline_employment")
            metrics["employment_change"] = outcomes["employment"] - outcomes["baseline_employment"]
        end

        push!(results, ScenarioResult(scenario, outcomes, metrics, now()))
    end

    return results
end

"""
Compare scenarios side-by-side
"""
function compare_scenarios(results::Vector{ScenarioResult})::Dict{String, Any}

    comparison = Dict{String, Any}()

    # Get all outcome keys
    all_keys = Set{String}()
    for result in results
        union!(all_keys, keys(result.outcomes))
    end

    # Build comparison table
    comparison_table = Dict{String, Dict{String, Float64}}()

    for key in all_keys
        comparison_table[key] = Dict{String, Float64}()
        for result in results
            if haskey(result.outcomes, key)
                comparison_table[key][result.scenario.name] = result.outcomes[key]
            end
        end
    end

    comparison["outcomes"] = comparison_table

    # Best and worst scenarios for each metric
    best_worst = Dict{String, Dict{String, String}}()

    for (metric, values) in comparison_table
        if !isempty(values)
            sorted = sort(collect(values), by=x->x[2], rev=true)
            best_worst[metric] = Dict(
                "best" => sorted[1][1],
                "worst" => sorted[end][1]
            )
        end
    end

    comparison["best_worst"] = best_worst

    # Probability-weighted average
    weighted_outcomes = Dict{String, Float64}()
    total_prob = sum(r.scenario.probability for r in results)

    for key in all_keys
        weighted_sum = 0.0
        for result in results
            if haskey(result.outcomes, key)
                weighted_sum += result.outcomes[key] * result.scenario.probability
            end
        end
        weighted_outcomes[key] = weighted_sum / total_prob
    end

    comparison["weighted_average"] = weighted_outcomes

    return comparison
end

"""
Sensitivity analysis - vary one parameter at a time
"""
function sensitivity_analysis(
    base_assumptions::Dict{String, Float64},
    parameter::String,
    value_range::Vector{Float64},
    model_func::Function,
    outcome_key::String
)::SensitivityAnalysis

    outcomes = Float64[]

    base_outcome = model_func(base_assumptions)[outcome_key]

    for value in value_range
        # Create modified assumptions
        assumptions = copy(base_assumptions)
        assumptions[parameter] = value

        # Run model
        result = model_func(assumptions)
        push!(outcomes, result[outcome_key])
    end

    # Calculate elasticity (percentage change in outcome / percentage change in input)
    if length(value_range) >= 2 && base_assumptions[parameter] != 0
        base_value = base_assumptions[parameter]
        idx = findfirst(x -> x == base_value, value_range)

        if !isnothing(idx) && idx < length(value_range)
            Δinput_pct = ((value_range[idx+1] - base_value) / base_value) * 100
            Δoutcome_pct = ((outcomes[idx+1] - base_outcome) / base_outcome) * 100
            elasticity = Δoutcome_pct / Δinput_pct
        else
            elasticity = 0.0
        end
    else
        elasticity = 0.0
    end

    return SensitivityAnalysis(parameter, value_range, outcomes, elasticity)
end

"""
Multi-parameter sensitivity analysis (tornado diagram data)
"""
function tornado_analysis(
    base_assumptions::Dict{String, Float64},
    parameters::Vector{String},
    variation_pct::Float64,  # e.g., 0.1 for ±10%
    model_func::Function,
    outcome_key::String
)::Vector{Tuple{String, Float64, Float64, Float64}}

    results = Tuple{String, Float64, Float64, Float64}[]

    base_outcome = model_func(base_assumptions)[outcome_key]

    for param in parameters
        if !haskey(base_assumptions, param)
            continue
        end

        base_value = base_assumptions[param]

        # Test low value
        assumptions_low = copy(base_assumptions)
        assumptions_low[param] = base_value * (1 - variation_pct)
        outcome_low = model_func(assumptions_low)[outcome_key]

        # Test high value
        assumptions_high = copy(base_assumptions)
        assumptions_high[param] = base_value * (1 + variation_pct)
        outcome_high = model_func(assumptions_high)[outcome_key]

        # Calculate swing
        swing = abs(outcome_high - outcome_low)

        push!(results, (param, outcome_low, base_outcome, outcome_high))
    end

    # Sort by swing (largest impact first)
    sort!(results, by=x -> abs(x[4] - x[2]), rev=true)

    return results
end

"""
What-if analysis: find input values that achieve target outcome
"""
function what_if_analysis(
    base_assumptions::Dict{String, Float64},
    parameter::String,
    target_outcome::Float64,
    model_func::Function,
    outcome_key::String;
    max_iterations::Int=100,
    tolerance::Float64=0.01
)::Union{Float64, Nothing}

    if !haskey(base_assumptions, parameter)
        return nothing
    end

    # Binary search approach
    base_value = base_assumptions[parameter]
    low = base_value * 0.5
    high = base_value * 1.5

    for _ in 1:max_iterations
        mid = (low + high) / 2.0

        assumptions = copy(base_assumptions)
        assumptions[parameter] = mid

        outcome = model_func(assumptions)[outcome_key]

        if abs(outcome - target_outcome) < tolerance
            return mid
        end

        if outcome < target_outcome
            low = mid
        else
            high = mid
        end
    end

    return nothing  # Could not converge
end

"""
Generate scenario report
"""
function generate_scenario_report(
    results::Vector{ScenarioResult},
    comparison::Dict{String, Any}
)::String

    report = """
    # Scenario Analysis Report

    Generated: $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))

    ## Scenarios Analyzed ($(length(results)))

    """

    for result in results
        report *= """
        ### $(result.scenario.name) (Probability: $(round(result.scenario.probability * 100, digits=1))%)

        $(result.scenario.description)

        **Key Outcomes:**
        """

        for (key, value) in result.outcomes
            report *= "\n- $key: $(round(value, digits=2))"
        end

        report *= "\n\n"
    end

    report *= """
    ## Comparison

    ### Probability-Weighted Outcomes

    """

    for (key, value) in comparison["weighted_average"]
        report *= "- $key: $(round(value, digits=2))\n"
    end

    report *= """

    ### Best and Worst Scenarios by Metric

    """

    for (metric, bw) in comparison["best_worst"]
        report *= "- **$metric**: Best = $(bw["best"]), Worst = $(bw["worst"])\n"
    end

    return report
end

export Scenario, ScenarioResult, SensitivityAnalysis
export create_scenario, analyze_scenarios, compare_scenarios
export sensitivity_analysis, tornado_analysis, what_if_analysis, generate_scenario_report
