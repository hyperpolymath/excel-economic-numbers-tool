# SPDX-License-Identifier: MPL-2.0
"""
WebSocket server for real-time collaboration features (v2.2 + v8.0).

Provides real-time updates, co-editing, and presence indicators.
"""

using HTTP, Sockets, JSON3

mutable struct CollaborationSession
    session_id::String
    users::Dict{String, Dict{String, Any}}
    document::Dict{String, Any}
    operations::Vector{Dict{String, Any}}
    created_at::DateTime
    last_activity::DateTime
end

"""
WebSocket collaboration server.
"""
mutable struct CollaborationServer
    sessions::Dict{String, CollaborationSession}
    connections::Dict{String, HTTP.WebSockets.WebSocket}

    function CollaborationServer()
        new(Dict{String, CollaborationSession}(), Dict{String, HTTP.WebSockets.WebSocket}())
    end
end

"""
Handle WebSocket connection for collaboration.
"""
function handle_collaboration_ws(server::CollaborationServer, ws::HTTP.WebSockets.WebSocket)
    user_id = nothing
    session_id = nothing

    try
        while !eof(ws)
            msg = String(readavailable(ws))
            data = JSON3.read(msg)

            if data.type == "join"
                user_id = data.user_id
                session_id = data.session_id

                # Add user to session
                if !haskey(server.sessions, session_id)
                    server.sessions[session_id] = CollaborationSession(
                        session_id,
                        Dict{String, Dict{String, Any}}(),
                        Dict{String, Any}(),
                        Vector{Dict{String, Any}}(),
                        now(),
                        now()
                    )
                end

                session = server.sessions[session_id]
                session.users[user_id] = Dict(
                    "name" => data.user_name,
                    "cursor" => nothing,
                    "selection" => nothing,
                    "joined_at" => now()
                )

                server.connections[user_id] = ws

                # Broadcast user joined
                broadcast(server, session_id, Dict(
                    "type" => "user_joined",
                    "user_id" => user_id,
                    "user_name" => data.user_name
                ))

            elseif data.type == "operation"
                # Apply operational transform
                operation = data.operation
                push!(server.sessions[session_id].operations, operation)

                # Broadcast operation to all users in session
                broadcast(server, session_id, Dict(
                    "type" => "operation",
                    "user_id" => user_id,
                    "operation" => operation
                ), exclude_user=user_id)

            elseif data.type == "cursor"
                # Update cursor position
                if haskey(server.sessions, session_id)
                    server.sessions[session_id].users[user_id]["cursor"] = data.position

                    broadcast(server, session_id, Dict(
                        "type" => "cursor_update",
                        "user_id" => user_id,
                        "position" => data.position
                    ), exclude_user=user_id)
                end
            end
        end
    catch e
        @error "WebSocket error" exception=e
    finally
        # Clean up
        if !isnothing(user_id) && !isnothing(session_id)
            if haskey(server.sessions, session_id)
                delete!(server.sessions[session_id].users, user_id)
                delete!(server.connections, user_id)

                broadcast(server, session_id, Dict(
                    "type" => "user_left",
                    "user_id" => user_id
                ))
            end
        end
    end
end

"""
Broadcast message to all users in a session.
"""
function broadcast(server::CollaborationServer, session_id::String, message::Dict; exclude_user=nothing)
    if !haskey(server.sessions, session_id)
        return
    end

    session = server.sessions[session_id]
    msg_json = JSON3.write(message)

    for (user_id, user_data) in session.users
        if user_id != exclude_user && haskey(server.connections, user_id)
            try
                write(server.connections[user_id], msg_json)
            catch e
                @error "Failed to send to user" user_id exception=e
            end
        end
    end
end
