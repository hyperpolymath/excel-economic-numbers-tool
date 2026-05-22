# SPDX-License-Identifier: MPL-2.0
"""
Webhook Integration System - v9.0

Trigger external workflows based on events.
"""

using HTTP, JSON3, UUIDs, Dates

@enum WebhookEvent begin
    DATA_UPDATED
    ANALYSIS_COMPLETED
    REPORT_GENERATED
    ALERT_TRIGGERED
    USER_ACTION
    SCHEDULE_RUN
end

struct WebhookConfig
    id::UUID
    name::String
    url::String
    events::Vector{WebhookEvent}
    secret::String
    headers::Dict{String, String}
    enabled::Bool
    retry_count::Int
    timeout_seconds::Int
    created_at::DateTime
end

struct WebhookDelivery
    id::UUID
    webhook_id::UUID
    event::WebhookEvent
    payload::Dict{String, Any}
    response_status::Union{Int, Nothing}
    response_body::Union{String, Nothing}
    delivered_at::DateTime
    duration_ms::Int
    success::Bool
end

struct WebhookManager
    webhooks::Dict{UUID, WebhookConfig}
    deliveries::Vector{WebhookDelivery}
    max_deliveries::Int
end

"""
Initialize webhook manager
"""
function WebhookManager(max_deliveries::Int=1000)
    return WebhookManager(
        Dict{UUID, WebhookConfig}(),
        WebhookDelivery[],
        max_deliveries
    )
end

"""
Register a webhook
"""
function register_webhook!(
    manager::WebhookManager,
    name::String,
    url::String,
    events::Vector{WebhookEvent};
    secret::String=bytes2hex(rand(UInt8, 32)),
    headers::Dict{String, String}=Dict{String, String}(),
    retry_count::Int=3,
    timeout_seconds::Int=30
)::UUID

    webhook_id = uuid4()

    config = WebhookConfig(
        webhook_id,
        name,
        url,
        events,
        secret,
        headers,
        true,
        retry_count,
        timeout_seconds,
        now()
    )

    manager.webhooks[webhook_id] = config

    @info "Registered webhook: $name ($webhook_id)"

    return webhook_id
end

"""
Trigger webhook event
"""
function trigger_event!(
    manager::WebhookManager,
    event::WebhookEvent,
    payload::Dict{String, Any}
)::Vector{UUID}

    triggered_webhooks = UUID[]

    for (webhook_id, config) in manager.webhooks
        if !config.enabled
            continue
        end

        if !(event in config.events)
            continue
        end

        delivery_id = deliver_webhook!(manager, webhook_id, event, payload)
        if !isnothing(delivery_id)
            push!(triggered_webhooks, delivery_id)
        end
    end

    return triggered_webhooks
end

"""
Deliver webhook payload
"""
function deliver_webhook!(
    manager::WebhookManager,
    webhook_id::UUID,
    event::WebhookEvent,
    payload::Dict{String, Any}
)::Union{UUID, Nothing}

    if !haskey(manager.webhooks, webhook_id)
        @warn "Webhook not found: $webhook_id"
        return nothing
    end

    config = manager.webhooks[webhook_id]
    delivery_id = uuid4()

    # Prepare payload
    full_payload = Dict{String, Any}(
        "event" => string(event),
        "webhook_id" => string(webhook_id),
        "timestamp" => string(now()),
        "data" => payload
    )

    # Generate signature (HMAC-SHA256)
    payload_json = JSON3.write(full_payload)
    signature = bytes2hex(sha256(config.secret * payload_json))

    # Prepare headers
    request_headers = copy(config.headers)
    request_headers["Content-Type"] = "application/json"
    request_headers["X-Webhook-Signature"] = signature
    request_headers["X-Webhook-Event"] = string(event)
    request_headers["X-Webhook-Delivery"] = string(delivery_id)

    # Attempt delivery with retries
    attempts = 0
    success = false
    response_status = nothing
    response_body = nothing
    start_time = time()

    while attempts < config.retry_count && !success
        attempts += 1

        try
            response = HTTP.post(
                config.url,
                request_headers,
                payload_json,
                readtimeout=config.timeout_seconds
            )

            response_status = response.status
            response_body = String(response.body)
            success = 200 <= response_status < 300

            if success
                break
            else
                @warn "Webhook delivery failed" webhook=config.name status=response_status attempt=attempts
            end
        catch e
            @error "Webhook delivery error" webhook=config.name exception=e attempt=attempts

            if attempts < config.retry_count
                # Exponential backoff
                sleep(2^(attempts - 1))
            end
        end
    end

    duration_ms = Int(round((time() - start_time) * 1000))

    # Record delivery
    delivery = WebhookDelivery(
        delivery_id,
        webhook_id,
        event,
        payload,
        response_status,
        response_body,
        now(),
        duration_ms,
        success
    )

    push!(manager.deliveries, delivery)

    # Trim old deliveries
    if length(manager.deliveries) > manager.max_deliveries
        deleteat!(manager.deliveries, 1:(length(manager.deliveries) - manager.max_deliveries))
    end

    if success
        @info "Webhook delivered successfully" webhook=config.name delivery_id=delivery_id duration_ms=duration_ms
    else
        @error "Webhook delivery failed after retries" webhook=config.name delivery_id=delivery_id
    end

    return delivery_id
end

"""
Disable webhook
"""
function disable_webhook!(manager::WebhookManager, webhook_id::UUID)::Bool
    if !haskey(manager.webhooks, webhook_id)
        return false
    end

    config = manager.webhooks[webhook_id]
    manager.webhooks[webhook_id] = WebhookConfig(
        config.id,
        config.name,
        config.url,
        config.events,
        config.secret,
        config.headers,
        false,  # disabled
        config.retry_count,
        config.timeout_seconds,
        config.created_at
    )

    @info "Disabled webhook: $(config.name)"
    return true
end

"""
Enable webhook
"""
function enable_webhook!(manager::WebhookManager, webhook_id::UUID)::Bool
    if !haskey(manager.webhooks, webhook_id)
        return false
    end

    config = manager.webhooks[webhook_id]
    manager.webhooks[webhook_id] = WebhookConfig(
        config.id,
        config.name,
        config.url,
        config.events,
        config.secret,
        config.headers,
        true,  # enabled
        config.retry_count,
        config.timeout_seconds,
        config.created_at
    )

    @info "Enabled webhook: $(config.name)"
    return true
end

"""
Delete webhook
"""
function delete_webhook!(manager::WebhookManager, webhook_id::UUID)::Bool
    if !haskey(manager.webhooks, webhook_id)
        return false
    end

    config = manager.webhooks[webhook_id]
    delete!(manager.webhooks, webhook_id)

    @info "Deleted webhook: $(config.name)"
    return true
end

"""
Get webhook delivery history
"""
function get_delivery_history(
    manager::WebhookManager,
    webhook_id::UUID;
    limit::Int=100
)::Vector{WebhookDelivery}

    deliveries = filter(d -> d.webhook_id == webhook_id, manager.deliveries)

    # Sort by most recent first
    sort!(deliveries, by=d -> d.delivered_at, rev=true)

    return deliveries[1:min(limit, length(deliveries))]
end

"""
Get webhook statistics
"""
function get_webhook_stats(manager::WebhookManager, webhook_id::UUID)::Dict{String, Any}
    deliveries = filter(d -> d.webhook_id == webhook_id, manager.deliveries)

    if isempty(deliveries)
        return Dict(
            "total_deliveries" => 0,
            "successful_deliveries" => 0,
            "failed_deliveries" => 0,
            "success_rate" => 0.0,
            "avg_duration_ms" => 0.0
        )
    end

    successful = count(d -> d.success, deliveries)
    failed = length(deliveries) - successful
    avg_duration = mean([d.duration_ms for d in deliveries])

    return Dict(
        "total_deliveries" => length(deliveries),
        "successful_deliveries" => successful,
        "failed_deliveries" => failed,
        "success_rate" => successful / length(deliveries),
        "avg_duration_ms" => round(avg_duration, digits=2)
    )
end

"""
List all webhooks
"""
function list_webhooks(manager::WebhookManager; enabled_only::Bool=false)::Vector{WebhookConfig}
    webhooks = collect(values(manager.webhooks))

    if enabled_only
        filter!(w -> w.enabled, webhooks)
    end

    return webhooks
end

export WebhookEvent, WebhookConfig, WebhookDelivery, WebhookManager
export register_webhook!, trigger_event!, deliver_webhook!
export disable_webhook!, enable_webhook!, delete_webhook!
export get_delivery_history, get_webhook_stats, list_webhooks
