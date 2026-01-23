# SPDX-License-Identifier: PMPL-1.0-or-later
"""
Authentication middleware for Economic Toolkit REST API.

Supports API key authentication with Bearer tokens.
"""

using HTTP
using JSON3
using SHA

"""
Simple API key authentication middleware.
Checks for Bearer token in Authorization header.
"""
struct APIKeyAuth
    api_keys::Set{String}
    enabled::Bool

    function APIKeyAuth(keys::Vector{String}=String[]; enabled::Bool=true)
        new(Set(keys), enabled)
    end
end

"""
Middleware function to validate API keys.
"""
function authenticate(auth::APIKeyAuth)
    return function(handler)
        return function(req::HTTP.Request)
            if !auth.enabled
                return handler(req)
            end

            # Check for Authorization header
            if !haskey(req.headers, "Authorization")
                return HTTP.Response(401, JSON3.write(Dict(
                    "error" => "Unauthorized",
                    "message" => "Missing Authorization header"
                )))
            end

            auth_header = req.headers["Authorization"]

            # Extract Bearer token
            if !startswith(auth_header, "Bearer ")
                return HTTP.Response(401, JSON3.write(Dict(
                    "error" => "Unauthorized",
                    "message" => "Invalid Authorization format. Use: Bearer <token>"
                )))
            end

            token = replace(auth_header, "Bearer " => "")

            # Validate token
            if token ∉ auth.api_keys
                return HTTP.Response(403, JSON3.write(Dict(
                    "error" => "Forbidden",
                    "message" => "Invalid API key"
                )))
            end

            # Token valid, proceed to handler
            return handler(req)
        end
    end
end

"""
Generate a new API key.
"""
function generate_api_key(prefix::String="etk")::String
    random_bytes = rand(UInt8, 32)
    hash_value = bytes2hex(sha256(random_bytes))
    return "$(prefix)_$(hash_value[1:40])"
end
