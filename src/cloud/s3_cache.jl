# SPDX-License-Identifier: PMPL-1.0-or-later
"""
Cloud storage backend for cache synchronization (v2.2).

Supports S3-compatible storage for distributed caching.
"""

using HTTP, JSON3, SHA, Dates

"""
S3-compatible cloud cache backend.
"""
struct S3Cache
    endpoint::String
    bucket::String
    access_key::String
    secret_key::String
    region::String

    function S3Cache(endpoint::String, bucket::String, access_key::String, secret_key::String; region::String="us-east-1")
        new(endpoint, bucket, access_key, secret_key, region)
    end
end

"""
Generate S3 signature v4.
"""
function sign_request(cache::S3Cache, method::String, path::String, headers::Dict{String,String}, payload::String="")
    timestamp = Dates.format(now(UTC), "yyyymmddTHHMMSSZ")
    datestamp = Dates.format(now(UTC), "yyyymmdd")

    # Create canonical request
    canonical_uri = path
    canonical_querystring = ""
    canonical_headers = join(["$k:$v\n" for (k,v) in sort(collect(headers))], "")
    signed_headers = join(sort(collect(keys(headers))), ";")
    payload_hash = bytes2hex(sha256(payload))

    canonical_request = "$method\n$canonical_uri\n$canonical_querystring\n$canonical_headers\n$signed_headers\n$payload_hash"

    # Create string to sign
    algorithm = "AWS4-HMAC-SHA256"
    credential_scope = "$datestamp/$(cache.region)/s3/aws4_request"
    string_to_sign = "$algorithm\n$timestamp\n$credential_scope\n$(bytes2hex(sha256(canonical_request)))"

    # Calculate signature
    k_date = hmac_sha256("AWS4$(cache.secret_key)", datestamp)
    k_region = hmac_sha256(k_date, cache.region)
    k_service = hmac_sha256(k_region, "s3")
    k_signing = hmac_sha256(k_service, "aws4_request")
    signature = bytes2hex(hmac_sha256(k_signing, string_to_sign))

    # Create authorization header
    authorization = "$algorithm Credential=$(cache.access_key)/$credential_scope, SignedHeaders=$signed_headers, Signature=$signature"

    return authorization, timestamp
end

"""
Store data in S3 cache.
"""
function set_cached(cache::S3Cache, key::String, value::Any, ttl::Int=3600)
    path = "/$(cache.bucket)/$key"
    payload = JSON3.write(Dict("value" => value, "expires_at" => now() + Second(ttl)))

    headers = Dict(
        "host" => cache.endpoint,
        "x-amz-content-sha256" => bytes2hex(sha256(payload))
    )

    authorization, timestamp = sign_request(cache, "PUT", path, headers, payload)
    headers["Authorization"] = authorization
    headers["x-amz-date"] = timestamp

    url = "https://$(cache.endpoint)$path"

    try
        HTTP.put(url, headers=headers, body=payload)
        return true
    catch e
        @error "Failed to store in S3 cache" key exception=e
        return false
    end
end

"""
Retrieve data from S3 cache.
"""
function get_cached(cache::S3Cache, key::String)
    path = "/$(cache.bucket)/$key"

    headers = Dict(
        "host" => cache.endpoint
    )

    authorization, timestamp = sign_request(cache, "GET", path, headers)
    headers["Authorization"] = authorization
    headers["x-amz-date"] = timestamp

    url = "https://$(cache.endpoint)$path"

    try
        response = HTTP.get(url, headers=headers)
        data = JSON3.read(String(response.body))

        # Check expiration
        if haskey(data, "expires_at") && DateTime(data.expires_at) < now()
            return nothing
        end

        return data.value
    catch e
        if e isa HTTP.ExceptionRequest.StatusError && e.status == 404
            return nothing
        end
        @error "Failed to retrieve from S3 cache" key exception=e
        return nothing
    end
end

# Helper for HMAC-SHA256
function hmac_sha256(key, message)
    return hmac(sha256, key, message)
end
