"""
Constraint Propagation System

Implements constraint solving for economic identities and relationships.
Enforces identities like: GDP = C + I + G + NX

Supports literate programming approach where users define relationships
and the system maintains consistency.
"""

using LinearAlgebra
using SparseArrays

"""
    Constraint

Represents an economic constraint/identity.

# Fields
- `name::String`: Constraint name
- `equation::String`: Human-readable equation (e.g., "GDP = C + I + G + NX")
- `variables::Vector{String}`: Variables in constraint
- `coefficients::Vector{Float64}`: Coefficients for each variable
- `rhs::Float64`: Right-hand side value
"""
struct Constraint
    name::String
    equation::String
    variables::Vector{String}
    coefficients::Vector{Float64}
    rhs::Float64
end

"""
    ConstraintSystem

Collection of constraints with variable values.

# Fields
- `constraints::Vector{Constraint}`: List of constraints
- `variables::Dict{String, Float64}`: Variable values
- `fixed::Set{String}`: Variables that are fixed (user-defined)
"""
mutable struct ConstraintSystem
    constraints::Vector{Constraint}
    variables::Dict{String, Float64}
    fixed::Set{String}

    ConstraintSystem() = new(Constraint[], Dict{String, Float64}(), Set{String}())
end

"""
    add_constraint(system::ConstraintSystem, name::String, equation::String,
                   variables::Vector{String}, coefficients::Vector{Float64}, rhs::Float64)

Add a constraint to the system.

# Example
```julia
system = ConstraintSystem()
# GDP = C + I + G + NX
add_constraint(system, "GDP_identity", "GDP = C + I + G + NX",
               ["GDP", "C", "I", "G", "NX"],
               [1.0, -1.0, -1.0, -1.0, -1.0],
               0.0)
```
"""
function add_constraint(system::ConstraintSystem, name::String, equation::String,
                        variables::Vector{String}, coefficients::Vector{Float64}, rhs::Float64)
    if length(variables) != length(coefficients)
        throw(ArgumentError("Variables and coefficients must have same length"))
    end

    constraint = Constraint(name, equation, variables, coefficients, rhs)
    push!(system.constraints, constraint)
end

"""
    set_variable(system::ConstraintSystem, var::String, value::Float64; fixed::Bool=false)

Set a variable value in the system.

# Arguments
- `system::ConstraintSystem`: The constraint system
- `var::String`: Variable name
- `value::Float64`: Variable value
- `fixed::Bool`: If true, this variable won't be changed by solver
"""
function set_variable(system::ConstraintSystem, var::String, value::Float64; fixed::Bool=false)
    system.variables[var] = value

    if fixed
        push!(system.fixed, var)
    end
end

"""
    get_variable(system::ConstraintSystem, var::String)::Union{Float64, Nothing}

Get a variable value from the system.
"""
function get_variable(system::ConstraintSystem, var::String)::Union{Float64, Nothing}
    return get(system.variables, var, nothing)
end

"""
    solve_constraints(system::ConstraintSystem; max_iterations::Int=100, tolerance::Float64=1e-6)::Bool

Solve the constraint system to find consistent variable values.

Uses iterative method to satisfy all constraints while respecting fixed variables.

# Arguments
- `system::ConstraintSystem`: The constraint system
- `max_iterations::Int`: Maximum iterations for convergence
- `tolerance::Float64`: Convergence tolerance

# Returns
- `Bool`: true if converged, false otherwise
"""
function solve_constraints(system::ConstraintSystem; max_iterations::Int=100, tolerance::Float64=1e-6)::Bool
    if isempty(system.constraints)
        return true
    end

    # Collect all variables
    all_vars = Set{String}()
    for constraint in system.constraints
        union!(all_vars, constraint.variables)
    end

    # Initialize unknown variables to 0
    for var in all_vars
        if !haskey(system.variables, var)
            system.variables[var] = 0.0
        end
    end

    # Build system of equations: Ax = b
    # But we need to handle fixed variables

    free_vars = setdiff(all_vars, system.fixed)
    n_constraints = length(system.constraints)
    n_free = length(free_vars)

    if n_free == 0
        # All variables fixed, just check consistency
        return check_constraints(system, tolerance)
    end

    # Iterative solver (Gauss-Seidel style)
    for iteration in 1:max_iterations
        max_change = 0.0

        for constraint in system.constraints
            # For each constraint, try to adjust one free variable to satisfy it
            residual = constraint.rhs

            # Calculate current value: Σ(coef * var)
            for (i, var) in enumerate(constraint.variables)
                residual -= constraint.coefficients[i] * system.variables[var]
            end

            # If residual is small enough, constraint is satisfied
            if abs(residual) < tolerance
                continue
            end

            # Find a free variable to adjust
            adjusted = false
            for (i, var) in enumerate(constraint.variables)
                if var in free_vars && constraint.coefficients[i] != 0
                    # Adjust this variable
                    adjustment = residual / constraint.coefficients[i]
                    system.variables[var] += adjustment
                    max_change = max(max_change, abs(adjustment))
                    adjusted = true
                    break
                end
            end

            if !adjusted
                @warn "Could not adjust constraint" constraint.name
            end
        end

        # Check for convergence
        if max_change < tolerance
            @info "Constraint system converged" iteration
            return true
        end
    end

    @warn "Constraint system did not converge" max_iterations
    return false
end

"""
    check_constraints(system::ConstraintSystem, tolerance::Float64=1e-6)::Bool

Check if all constraints are currently satisfied.

# Arguments
- `system::ConstraintSystem`: The constraint system
- `tolerance::Float64`: Tolerance for equality

# Returns
- `Bool`: true if all constraints satisfied, false otherwise
"""
function check_constraints(system::ConstraintSystem, tolerance::Float64=1e-6)::Bool
    all_satisfied = true

    for constraint in system.constraints
        residual = constraint.rhs

        for (i, var) in enumerate(constraint.variables)
            val = get(system.variables, var, 0.0)
            residual -= constraint.coefficients[i] * val
        end

        if abs(residual) > tolerance
            @warn "Constraint not satisfied" constraint.name residual
            all_satisfied = false
        end
    end

    return all_satisfied
end

"""
    gdp_identity_system(; C::Union{Float64, Nothing}=nothing,
                          I::Union{Float64, Nothing}=nothing,
                          G::Union{Float64, Nothing}=nothing,
                          NX::Union{Float64, Nothing}=nothing,
                          GDP::Union{Float64, Nothing}=nothing)::ConstraintSystem

Create a constraint system for GDP identity: GDP = C + I + G + NX

Provide known values, system will solve for unknown.

# Example
```julia
system = gdp_identity_system(C=14000.0, I=3000.0, G=3500.0, NX=-500.0)
solve_constraints(system)
gdp = get_variable(system, "GDP")  # Returns 20000.0
```
"""
function gdp_identity_system(; C::Union{Float64, Nothing}=nothing,
                               I::Union{Float64, Nothing}=nothing,
                               G::Union{Float64, Nothing}=nothing,
                               NX::Union{Float64, Nothing}=nothing,
                               GDP::Union{Float64, Nothing}=nothing)::ConstraintSystem
    system = ConstraintSystem()

    # Add constraint: GDP - C - I - G - NX = 0
    add_constraint(system, "GDP_identity", "GDP = C + I + G + NX",
                   ["GDP", "C", "I", "G", "NX"],
                   [1.0, -1.0, -1.0, -1.0, -1.0],
                   0.0)

    # Set known values
    if C !== nothing
        set_variable(system, "C", C, fixed=true)
    end
    if I !== nothing
        set_variable(system, "I", I, fixed=true)
    end
    if G !== nothing
        set_variable(system, "G", G, fixed=true)
    end
    if NX !== nothing
        set_variable(system, "NX", NX, fixed=true)
    end
    if GDP !== nothing
        set_variable(system, "GDP", GDP, fixed=true)
    end

    return system
end

"""
    print_system(system::ConstraintSystem)

Print the current state of the constraint system.
"""
function print_system(system::ConstraintSystem)
    println("Constraint System:")
    println("==================")
    println("\nConstraints:")
    for constraint in system.constraints
        println("  $(constraint.name): $(constraint.equation)")
    end

    println("\nVariables:")
    for (var, val) in sort(collect(system.variables))
        fixed_str = var in system.fixed ? " (FIXED)" : ""
        println("  $var = $val$fixed_str")
    end

    println("\nSatisfied: $(check_constraints(system))")
end
