# SPDX-License-Identifier: MPL-2.0
"""
Plugin Architecture - v9.0

Extensible plugin system for custom data sources, formulas, and visualizations.
"""

using UUIDs, Dates, TOML

@enum PluginType DATA_SOURCE FORMULA VISUALIZATION EXPORT AUTHENTICATION

struct PluginManifest
    id::UUID
    name::String
    version::String
    description::String
    author::String
    license::String
    plugin_type::PluginType
    entry_point::String
    dependencies::Vector{String}
    permissions::Vector{String}
    config_schema::Dict{String, Any}
end

struct Plugin
    manifest::PluginManifest
    enabled::Bool
    installed_at::DateTime
    last_updated::DateTime
    config::Dict{String, Any}
end

struct PluginRegistry
    plugins::Dict{UUID, Plugin}
    enabled_plugins::Set{UUID}
    hooks::Dict{String, Vector{UUID}}
end

"""
Initialize plugin registry
"""
function PluginRegistry()
    return PluginRegistry(
        Dict{UUID, Plugin}(),
        Set{UUID}(),
        Dict{String, Vector{UUID}}()
    )
end

"""
Load plugin manifest from TOML
"""
function load_manifest(manifest_path::String)::PluginManifest
    data = TOML.parsefile(manifest_path)

    plugin_type_str = get(data, "type", "data_source")
    plugin_type = if plugin_type_str == "data_source"
        DATA_SOURCE
    elseif plugin_type_str == "formula"
        FORMULA
    elseif plugin_type_str == "visualization"
        VISUALIZATION
    elseif plugin_type_str == "export"
        EXPORT
    elseif plugin_type_str == "authentication"
        AUTHENTICATION
    else
        DATA_SOURCE
    end

    return PluginManifest(
        UUID(get(data, "id", string(uuid4()))),
        get(data, "name", "Unnamed Plugin"),
        get(data, "version", "0.1.0"),
        get(data, "description", ""),
        get(data, "author", "Unknown"),
        get(data, "license", "MIT"),
        plugin_type,
        get(data, "entry_point", "main.jl"),
        get(data, "dependencies", String[]),
        get(data, "permissions", String[]),
        get(data, "config_schema", Dict{String, Any}())
    )
end

"""
Register a plugin
"""
function register_plugin!(
    registry::PluginRegistry,
    manifest::PluginManifest,
    config::Dict{String, Any}=Dict{String, Any}()
)::UUID

    # Validate dependencies
    for dep in manifest.dependencies
        # Check if dependency is satisfied
        # In production, implement proper dependency resolution
    end

    # Create plugin
    plugin = Plugin(
        manifest,
        true,
        now(),
        now(),
        config
    )

    # Add to registry
    registry.plugins[manifest.id] = plugin
    push!(registry.enabled_plugins, manifest.id)

    @info "Registered plugin: $(manifest.name) v$(manifest.version)"

    return manifest.id
end

"""
Enable a plugin
"""
function enable_plugin!(registry::PluginRegistry, plugin_id::UUID)::Bool
    if !haskey(registry.plugins, plugin_id)
        @warn "Plugin not found: $plugin_id"
        return false
    end

    push!(registry.enabled_plugins, plugin_id)

    # Update plugin state
    plugin = registry.plugins[plugin_id]
    registry.plugins[plugin_id] = Plugin(
        plugin.manifest,
        true,
        plugin.installed_at,
        now(),
        plugin.config
    )

    @info "Enabled plugin: $(plugin.manifest.name)"
    return true
end

"""
Disable a plugin
"""
function disable_plugin!(registry::PluginRegistry, plugin_id::UUID)::Bool
    if !haskey(registry.plugins, plugin_id)
        @warn "Plugin not found: $plugin_id"
        return false
    end

    delete!(registry.enabled_plugins, plugin_id)

    # Update plugin state
    plugin = registry.plugins[plugin_id]
    registry.plugins[plugin_id] = Plugin(
        plugin.manifest,
        false,
        plugin.installed_at,
        now(),
        plugin.config
    )

    @info "Disabled plugin: $(plugin.manifest.name)"
    return true
end

"""
Unregister a plugin
"""
function unregister_plugin!(registry::PluginRegistry, plugin_id::UUID)::Bool
    if !haskey(registry.plugins, plugin_id)
        return false
    end

    plugin = registry.plugins[plugin_id]
    delete!(registry.plugins, plugin_id)
    delete!(registry.enabled_plugins, plugin_id)

    # Remove from all hooks
    for (_, plugin_list) in registry.hooks
        filter!(id -> id != plugin_id, plugin_list)
    end

    @info "Unregistered plugin: $(plugin.manifest.name)"
    return true
end

"""
Register a hook
"""
function register_hook!(
    registry::PluginRegistry,
    hook_name::String,
    plugin_id::UUID
)::Nothing

    if !haskey(registry.hooks, hook_name)
        registry.hooks[hook_name] = UUID[]
    end

    if !(plugin_id in registry.hooks[hook_name])
        push!(registry.hooks[hook_name], plugin_id)
    end

    return nothing
end

"""
Call a hook
"""
function call_hook(
    registry::PluginRegistry,
    hook_name::String,
    args::Dict{String, Any}=Dict{String, Any}()
)::Vector{Any}

    if !haskey(registry.hooks, hook_name)
        return Any[]
    end

    results = Any[]

    for plugin_id in registry.hooks[hook_name]
        if !(plugin_id in registry.enabled_plugins)
            continue
        end

        plugin = registry.plugins[plugin_id]

        try
            # In production, actually execute plugin code
            result = Dict(
                "plugin" => plugin.manifest.name,
                "status" => "success",
                "data" => args
            )
            push!(results, result)
        catch e
            @error "Hook execution failed" plugin=plugin.manifest.name exception=e
            push!(results, Dict(
                "plugin" => plugin.manifest.name,
                "status" => "error",
                "error" => string(e)
            ))
        end
    end

    return results
end

"""
Get plugin info
"""
function get_plugin_info(registry::PluginRegistry, plugin_id::UUID)::Union{Plugin, Nothing}
    return get(registry.plugins, plugin_id, nothing)
end

"""
List all plugins
"""
function list_plugins(
    registry::PluginRegistry;
    plugin_type::Union{PluginType, Nothing}=nothing,
    enabled_only::Bool=false
)::Vector{Plugin}

    plugins = collect(values(registry.plugins))

    # Filter by type
    if !isnothing(plugin_type)
        plugins = filter(p -> p.manifest.plugin_type == plugin_type, plugins)
    end

    # Filter by enabled status
    if enabled_only
        plugins = filter(p -> p.manifest.id in registry.enabled_plugins, plugins)
    end

    return plugins
end

"""
Update plugin configuration
"""
function update_plugin_config!(
    registry::PluginRegistry,
    plugin_id::UUID,
    config::Dict{String, Any}
)::Bool

    if !haskey(registry.plugins, plugin_id)
        return false
    end

    plugin = registry.plugins[plugin_id]

    # Validate config against schema
    # In production, implement proper JSON schema validation

    # Update plugin
    registry.plugins[plugin_id] = Plugin(
        plugin.manifest,
        plugin.enabled,
        plugin.installed_at,
        now(),
        config
    )

    @info "Updated config for plugin: $(plugin.manifest.name)"
    return true
end

"""
Check plugin permissions
"""
function check_permissions(plugin::Plugin, required_permission::String)::Bool
    return required_permission in plugin.manifest.permissions
end

"""
Export plugin registry to JSON
"""
function export_registry(registry::PluginRegistry)::String
    data = Dict(
        "plugins" => [
            Dict(
                "id" => string(p.manifest.id),
                "name" => p.manifest.name,
                "version" => p.manifest.version,
                "type" => string(p.manifest.plugin_type),
                "enabled" => p.enabled,
                "author" => p.manifest.author
            )
            for p in values(registry.plugins)
        ],
        "total_plugins" => length(registry.plugins),
        "enabled_count" => length(registry.enabled_plugins)
    )

    return JSON3.write(data)
end

export PluginType, PluginManifest, Plugin, PluginRegistry
export load_manifest, register_plugin!, enable_plugin!, disable_plugin!, unregister_plugin!
export register_hook!, call_hook, get_plugin_info, list_plugins, update_plugin_config!
export check_permissions, export_registry
