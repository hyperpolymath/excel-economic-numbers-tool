# SPDX-License-Identifier: MPL-2.0
"""
Economic Impact Modeling - v4.0

Input-output models, multiplier effects, and policy impact analysis.
"""

using LinearAlgebra, Statistics

struct InputOutputModel
    sectors::Vector{String}
    technical_coefficients::Matrix{Float64}  # A matrix
    leontief_inverse::Matrix{Float64}  # (I - A)^-1
    final_demand::Vector{Float64}
end

struct MultiplierAnalysis
    output_multipliers::Vector{Float64}
    employment_multipliers::Vector{Float64}
    income_multipliers::Vector{Float64}
    indirect_effects::Dict{String, Float64}
    induced_effects::Dict{String, Float64}
end

struct PolicyImpact
    policy_name::String
    direct_effect::Float64
    indirect_effect::Float64
    induced_effect::Float64
    total_effect::Float64
    affected_sectors::Dict{String, Float64}
    employment_impact::Float64
    gdp_impact::Float64
end

"""
Create an input-output model
"""
function create_io_model(
    sectors::Vector{String},
    transaction_matrix::Matrix{Float64},  # Inter-sector transactions
    total_outputs::Vector{Float64}
)::InputOutputModel

    n = length(sectors)

    # Calculate technical coefficients (A = Z / X)
    A = zeros(n, n)
    for i in 1:n
        for j in 1:n
            if total_outputs[j] > 0
                A[i, j] = transaction_matrix[i, j] / total_outputs[j]
            end
        end
    end

    # Calculate Leontief inverse: (I - A)^-1
    I = Matrix{Float64}(I, n, n)
    L = inv(I - A)

    # Final demand (simplified: total output - intermediate demand)
    intermediate_demand = sum(transaction_matrix, dims=2)[:]
    final_demand = total_outputs .- intermediate_demand

    return InputOutputModel(sectors, A, L, final_demand)
end

"""
Calculate multipliers
"""
function calculate_multipliers(
    model::InputOutputModel,
    employment_coefficients::Vector{Float64},  # Jobs per unit output
    income_coefficients::Vector{Float64}  # Income per unit output
)::MultiplierAnalysis

    n = length(model.sectors)

    # Output multipliers: column sums of Leontief inverse
    output_multipliers = vec(sum(model.leontief_inverse, dims=1))

    # Employment multipliers
    employment_multipliers = zeros(n)
    for j in 1:n
        for i in 1:n
            employment_multipliers[j] += employment_coefficients[i] * model.leontief_inverse[i, j]
        end
    end

    # Income multipliers
    income_multipliers = zeros(n)
    for j in 1:n
        for i in 1:n
            income_multipliers[j] += income_coefficients[i] * model.leontief_inverse[i, j]
        end
    end

    # Indirect effects (output multiplier - 1)
    indirect_effects = Dict{String, Float64}()
    for (i, sector) in enumerate(model.sectors)
        indirect_effects[sector] = output_multipliers[i] - 1.0
    end

    # Induced effects (simplified)
    induced_effects = Dict{String, Float64}()
    for (i, sector) in enumerate(model.sectors)
        induced_effects[sector] = income_multipliers[i] * 0.5  # Assume 50% MPC
    end

    return MultiplierAnalysis(
        output_multipliers,
        employment_multipliers,
        income_multipliers,
        indirect_effects,
        induced_effects
    )
end

"""
Analyze policy impact
"""
function analyze_policy_impact(
    model::InputOutputModel,
    multipliers::MultiplierAnalysis,
    policy_name::String,
    direct_spending::Dict{String, Float64};  # Spending by sector
    employment_coefficients::Vector{Float64}=Float64[]
)::PolicyImpact

    n = length(model.sectors)

    # Create demand shock vector
    demand_shock = zeros(n)
    direct_effect = 0.0

    for (sector, amount) in direct_spending
        idx = findfirst(s -> s == sector, model.sectors)
        if !isnothing(idx)
            demand_shock[idx] = amount
            direct_effect += amount
        end
    end

    # Calculate total output effect using Leontief inverse
    total_output_change = model.leontief_inverse * demand_shock
    total_effect = sum(total_output_change)

    # Indirect effect (total - direct)
    indirect_effect = total_effect - direct_effect

    # Induced effect (simplified: income multiplier effect)
    induced_effect = 0.0
    for (i, sector) in enumerate(model.sectors)
        if haskey(direct_spending, sector)
            induced_effect += direct_spending[sector] * get(multipliers.induced_effects, sector, 0.0)
        end
    end

    # Affected sectors
    affected_sectors = Dict{String, Float64}()
    for (i, sector) in enumerate(model.sectors)
        if total_output_change[i] > 0.01  # Threshold for significance
            affected_sectors[sector] = total_output_change[i]
        end
    end

    # Employment impact
    employment_impact = 0.0
    if !isempty(employment_coefficients) && length(employment_coefficients) == n
        employment_impact = sum(employment_coefficients .* total_output_change)
    end

    # GDP impact (as fraction of total effect)
    gdp_impact = total_effect * 0.7  # Simplified: assume 70% of output is GDP

    return PolicyImpact(
        policy_name,
        direct_effect,
        indirect_effect,
        induced_effect,
        total_effect,
        affected_sectors,
        employment_impact,
        gdp_impact
    )
end

"""
Regional economic impact
"""
function regional_impact_analysis(
    baseline_gdp::Float64,
    baseline_employment::Float64,
    shock_magnitude::Float64,
    regional_multiplier::Float64=1.5
)::Dict{String, Float64}

    # Direct impact
    direct_gdp = shock_magnitude
    direct_employment = shock_magnitude / (baseline_gdp / baseline_employment)

    # Indirect impact (through supply chain)
    indirect_gdp = direct_gdp * (regional_multiplier - 1.0) * 0.6
    indirect_employment = direct_employment * (regional_multiplier - 1.0) * 0.6

    # Induced impact (through household spending)
    induced_gdp = direct_gdp * (regional_multiplier - 1.0) * 0.4
    induced_employment = direct_employment * (regional_multiplier - 1.0) * 0.4

    return Dict(
        "direct_gdp" => direct_gdp,
        "indirect_gdp" => indirect_gdp,
        "induced_gdp" => induced_gdp,
        "total_gdp" => direct_gdp + indirect_gdp + induced_gdp,
        "direct_employment" => direct_employment,
        "indirect_employment" => indirect_employment,
        "induced_employment" => induced_employment,
        "total_employment" => direct_employment + indirect_employment + induced_employment,
        "multiplier" => regional_multiplier
    )
end

"""
Generate impact report
"""
function generate_impact_report(impact::PolicyImpact)::String
    report = """
    # Economic Impact Analysis: $(impact.policy_name)

    Generated: $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))

    ## Summary

    **Total Economic Impact:** \$$(round(impact.total_effect, digits=2)) million

    ### Breakdown
    - **Direct Effect:** \$$(round(impact.direct_effect, digits=2)) million
    - **Indirect Effect:** \$$(round(impact.indirect_effect, digits=2)) million ($(round(impact.indirect_effect/impact.direct_effect*100, digits=1))% of direct)
    - **Induced Effect:** \$$(round(impact.induced_effect, digits=2)) million ($(round(impact.induced_effect/impact.direct_effect*100, digits=1))% of direct)

    **Multiplier:** $(round(impact.total_effect / impact.direct_effect, digits=2))x

    ### Employment Impact
    **Jobs Created/Supported:** $(round(impact.employment_impact, digits=0)) jobs

    ### GDP Impact
    **GDP Contribution:** \$$(round(impact.gdp_impact, digits=2)) million

    ## Affected Sectors

    """

    # Sort sectors by impact
    sorted_sectors = sort(collect(impact.affected_sectors), by=x->x[2], rev=true)

    for (sector, impact_value) in sorted_sectors
        pct = (impact_value / impact.total_effect) * 100
        report *= "- **$sector:** \$$(round(impact_value, digits=2)) million ($(round(pct, digits=1))%)\n"
    end

    report *= """

    ## Interpretation

    For every \$1 of direct spending, this policy generates \$$(round(impact.total_effect / impact.direct_effect, digits=2))
    in total economic activity. This includes supply chain effects (indirect) and household spending effects (induced).

    The policy is estimated to support $(round(impact.employment_impact, digits=0)) jobs and contribute
    \$$(round(impact.gdp_impact, digits=2)) million to GDP.
    """

    return report
end

export InputOutputModel, MultiplierAnalysis, PolicyImpact
export create_io_model, calculate_multipliers, analyze_policy_impact
export regional_impact_analysis, generate_impact_report
