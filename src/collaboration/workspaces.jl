# SPDX-License-Identifier: PMPL-1.0-or-later
"""
Team Workspaces - v8.0

Collaborative workspaces for teams to organize projects, data, and analyses.
"""

using UUIDs, Dates

@enum WorkspaceRole OWNER ADMIN MEMBER VIEWER

@enum ResourceType DASHBOARD REPORT MODEL DATASET ANALYSIS

struct WorkspaceMember
    user_id::String
    user_name::String
    email::String
    role::WorkspaceRole
    joined_at::DateTime
    last_active::DateTime
end

struct WorkspaceResource
    id::UUID
    type::ResourceType
    name::String
    description::String
    created_by::String
    created_at::DateTime
    updated_at::DateTime
    tags::Vector{String}
    metadata::Dict{String, Any}
end

struct Workspace
    id::UUID
    name::String
    description::String
    owner_id::String
    members::Vector{WorkspaceMember}
    resources::Vector{WorkspaceResource}
    shared_libraries::Vector{UUID}
    settings::Dict{String, Any}
    created_at::DateTime
    updated_at::DateTime
end

struct SharedLibrary
    id::UUID
    workspace_id::UUID
    name::String
    description::String
    series_ids::Vector{String}
    formulas::Dict{String, String}
    created_by::String
    created_at::DateTime
    updated_at::DateTime
end

"""
Create a new workspace
"""
function create_workspace(
    name::String,
    owner_id::String,
    owner_name::String,
    owner_email::String;
    description::String=""
)::Workspace

    workspace_id = uuid4()

    owner = WorkspaceMember(
        owner_id,
        owner_name,
        owner_email,
        OWNER,
        now(),
        now()
    )

    return Workspace(
        workspace_id,
        name,
        description,
        owner_id,
        [owner],
        WorkspaceResource[],
        UUID[],
        Dict{String, Any}(
            "visibility" => "private",
            "allow_guest_access" => false,
            "require_2fa" => false
        ),
        now(),
        now()
    )
end

"""
Add member to workspace
"""
function add_member!(
    workspace::Workspace,
    user_id::String,
    user_name::String,
    email::String,
    role::WorkspaceRole=MEMBER
)::Workspace

    # Check if already a member
    if any(m -> m.user_id == user_id, workspace.members)
        @warn "User $user_id is already a member"
        return workspace
    end

    new_member = WorkspaceMember(
        user_id,
        user_name,
        email,
        role,
        now(),
        now()
    )

    return Workspace(
        workspace.id,
        workspace.name,
        workspace.description,
        workspace.owner_id,
        vcat(workspace.members, [new_member]),
        workspace.resources,
        workspace.shared_libraries,
        workspace.settings,
        workspace.created_at,
        now()
    )
end

"""
Remove member from workspace
"""
function remove_member!(workspace::Workspace, user_id::String)::Workspace
    # Cannot remove owner
    if user_id == workspace.owner_id
        throw(ArgumentError("Cannot remove workspace owner"))
    end

    filtered_members = filter(m -> m.user_id != user_id, workspace.members)

    return Workspace(
        workspace.id,
        workspace.name,
        workspace.description,
        workspace.owner_id,
        filtered_members,
        workspace.resources,
        workspace.shared_libraries,
        workspace.settings,
        workspace.created_at,
        now()
    )
end

"""
Update member role
"""
function update_member_role!(
    workspace::Workspace,
    user_id::String,
    new_role::WorkspaceRole
)::Workspace

    # Cannot change owner role
    if user_id == workspace.owner_id && new_role != OWNER
        throw(ArgumentError("Cannot change owner role"))
    end

    updated_members = map(workspace.members) do member
        if member.user_id == user_id
            WorkspaceMember(
                member.user_id,
                member.user_name,
                member.email,
                new_role,
                member.joined_at,
                member.last_active
            )
        else
            member
        end
    end

    return Workspace(
        workspace.id,
        workspace.name,
        workspace.description,
        workspace.owner_id,
        updated_members,
        workspace.resources,
        workspace.shared_libraries,
        workspace.settings,
        workspace.created_at,
        now()
    )
end

"""
Add resource to workspace
"""
function add_resource!(
    workspace::Workspace,
    type::ResourceType,
    name::String,
    created_by::String;
    description::String="",
    tags::Vector{String}=String[],
    metadata::Dict{String, Any}=Dict{String, Any}()
)::Tuple{Workspace, UUID}

    resource_id = uuid4()

    resource = WorkspaceResource(
        resource_id,
        type,
        name,
        description,
        created_by,
        now(),
        now(),
        tags,
        metadata
    )

    updated_workspace = Workspace(
        workspace.id,
        workspace.name,
        workspace.description,
        workspace.owner_id,
        workspace.members,
        vcat(workspace.resources, [resource]),
        workspace.shared_libraries,
        workspace.settings,
        workspace.created_at,
        now()
    )

    return (updated_workspace, resource_id)
end

"""
Remove resource from workspace
"""
function remove_resource!(workspace::Workspace, resource_id::UUID)::Workspace
    filtered_resources = filter(r -> r.id != resource_id, workspace.resources)

    return Workspace(
        workspace.id,
        workspace.name,
        workspace.description,
        workspace.owner_id,
        workspace.members,
        filtered_resources,
        workspace.shared_libraries,
        workspace.settings,
        workspace.created_at,
        now()
    )
end

"""
Create shared library
"""
function create_shared_library(
    workspace_id::UUID,
    name::String,
    created_by::String;
    description::String="",
    series_ids::Vector{String}=String[],
    formulas::Dict{String, String}=Dict{String, String}()
)::SharedLibrary

    return SharedLibrary(
        uuid4(),
        workspace_id,
        name,
        description,
        series_ids,
        formulas,
        created_by,
        now(),
        now()
    )
end

"""
Add series to shared library
"""
function add_series_to_library!(
    library::SharedLibrary,
    series_id::String
)::SharedLibrary

    if series_id in library.series_ids
        return library
    end

    return SharedLibrary(
        library.id,
        library.workspace_id,
        library.name,
        library.description,
        vcat(library.series_ids, [series_id]),
        library.formulas,
        library.created_by,
        library.created_at,
        now()
    )
end

"""
Add formula to shared library
"""
function add_formula_to_library!(
    library::SharedLibrary,
    formula_name::String,
    formula_code::String
)::SharedLibrary

    updated_formulas = copy(library.formulas)
    updated_formulas[formula_name] = formula_code

    return SharedLibrary(
        library.id,
        library.workspace_id,
        library.name,
        library.description,
        library.series_ids,
        updated_formulas,
        library.created_by,
        library.created_at,
        now()
    )
end

"""
Check if user has permission
"""
function has_permission(
    workspace::Workspace,
    user_id::String,
    required_role::WorkspaceRole
)::Bool

    member = findfirst(m -> m.user_id == user_id, workspace.members)

    if isnothing(member)
        return false
    end

    user_role = workspace.members[member].role

    # Role hierarchy: OWNER > ADMIN > MEMBER > VIEWER
    role_levels = Dict(OWNER => 4, ADMIN => 3, MEMBER => 2, VIEWER => 1)

    return role_levels[user_role] >= role_levels[required_role]
end

"""
Get workspace statistics
"""
function get_workspace_stats(workspace::Workspace)::Dict{String, Any}
    return Dict(
        "member_count" => length(workspace.members),
        "resource_count" => length(workspace.resources),
        "shared_library_count" => length(workspace.shared_libraries),
        "resources_by_type" => Dict(
            string(type) => count(r -> r.type == type, workspace.resources)
            for type in instances(ResourceType)
        ),
        "active_members_30d" => count(
            m -> now() - m.last_active <= Day(30),
            workspace.members
        ),
        "created_days_ago" => (now() - workspace.created_at).value ÷ 86400000
    )
end

"""
Search resources in workspace
"""
function search_resources(
    workspace::Workspace,
    query::String;
    type_filter::Union{ResourceType, Nothing}=nothing,
    tag_filter::Vector{String}=String[]
)::Vector{WorkspaceResource}

    results = workspace.resources

    # Filter by type
    if !isnothing(type_filter)
        results = filter(r -> r.type == type_filter, results)
    end

    # Filter by tags
    if !isempty(tag_filter)
        results = filter(results) do resource
            any(tag -> tag in resource.tags, tag_filter)
        end
    end

    # Filter by query
    if !isempty(query)
        query_lower = lowercase(query)
        results = filter(results) do resource
            contains(lowercase(resource.name), query_lower) ||
            contains(lowercase(resource.description), query_lower)
        end
    end

    # Sort by most recent
    sort!(results, by=r -> r.updated_at, rev=true)

    return results
end

"""
Get recent activity
"""
function get_recent_activity(
    workspace::Workspace,
    limit::Int=50
)::Vector{Dict{String, Any}}

    activities = Dict{String, Any}[]

    # Resource creations
    for resource in workspace.resources
        push!(activities, Dict(
            "type" => "resource_created",
            "timestamp" => resource.created_at,
            "user_id" => resource.created_by,
            "resource_type" => string(resource.type),
            "resource_name" => resource.name
        ))
    end

    # Member joins
    for member in workspace.members[2:end]  # Skip owner
        push!(activities, Dict(
            "type" => "member_joined",
            "timestamp" => member.joined_at,
            "user_id" => member.user_id,
            "user_name" => member.user_name
        ))
    end

    # Sort by most recent
    sort!(activities, by=a -> a["timestamp"], rev=true)

    return activities[1:min(limit, length(activities))]
end

export WorkspaceRole, ResourceType, WorkspaceMember, WorkspaceResource, Workspace, SharedLibrary
export create_workspace, add_member!, remove_member!, update_member_role!
export add_resource!, remove_resource!
export create_shared_library, add_series_to_library!, add_formula_to_library!
export has_permission, get_workspace_stats, search_resources, get_recent_activity
