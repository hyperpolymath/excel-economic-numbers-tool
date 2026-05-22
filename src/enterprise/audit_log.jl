# SPDX-License-Identifier: MPL-2.0
"""
Audit Logging and Compliance - v5.0

Comprehensive audit trail for all user actions, data access, and system changes.
Supports GDPR, SOC 2, HIPAA compliance requirements.
"""

using Dates, JSON3, UUIDs

@enum AuditEventType begin
    USER_LOGIN
    USER_LOGOUT
    USER_FAILED_LOGIN
    DATA_ACCESS
    DATA_EXPORT
    DATA_MODIFICATION
    PERMISSION_CHANGE
    CONFIG_CHANGE
    API_CALL
    QUERY_EXECUTION
    REPORT_GENERATION
    SYSTEM_ERROR
end

@enum ComplianceFramework begin
    GDPR
    SOC2
    HIPAA
    PCI_DSS
    ISO27001
end

struct AuditEvent
    id::UUID
    timestamp::DateTime
    event_type::AuditEventType
    user_id::String
    user_email::String
    user_ip::String
    user_agent::String
    resource_type::String
    resource_id::String
    action::String
    result::String  # "success", "failure", "partial"
    details::Dict{String, Any}
    compliance_tags::Vector{ComplianceFramework}
    retention_until::DateTime
end

struct AuditLog
    events::Vector{AuditEvent}
    storage_path::String
    retention_days::Dict{AuditEventType, Int}
    compliance_mode::Bool
end

"""
Initialize audit log system
"""
function AuditLog(storage_path::String="./audit_logs"; compliance_mode::Bool=true)
    # Default retention periods (in days)
    retention_days = Dict(
        USER_LOGIN => 90,
        USER_LOGOUT => 90,
        USER_FAILED_LOGIN => 180,
        DATA_ACCESS => 365,
        DATA_EXPORT => 2555,  # 7 years for compliance
        DATA_MODIFICATION => 2555,
        PERMISSION_CHANGE => 2555,
        CONFIG_CHANGE => 1825,  # 5 years
        API_CALL => 90,
        QUERY_EXECUTION => 180,
        REPORT_GENERATION => 365,
        SYSTEM_ERROR => 365
    )

    return AuditLog(AuditEvent[], storage_path, retention_days, compliance_mode)
end

"""
Log an audit event
"""
function log_event!(
    audit_log::AuditLog;
    event_type::AuditEventType,
    user_id::String,
    user_email::String,
    user_ip::String="0.0.0.0",
    user_agent::String="Unknown",
    resource_type::String="",
    resource_id::String="",
    action::String,
    result::String="success",
    details::Dict{String, Any}=Dict{String, Any}(),
    compliance_tags::Vector{ComplianceFramework}=ComplianceFramework[]
)::UUID

    event_id = uuid4()
    timestamp = now(Dates.UTC)

    # Calculate retention date
    retention_days = get(audit_log.retention_days, event_type, 365)
    retention_until = timestamp + Day(retention_days)

    # Auto-tag compliance frameworks
    if audit_log.compliance_mode
        if event_type in [DATA_ACCESS, DATA_EXPORT, DATA_MODIFICATION]
            push!(compliance_tags, GDPR)
        end
        if event_type in [USER_LOGIN, PERMISSION_CHANGE, CONFIG_CHANGE]
            push!(compliance_tags, SOC2)
        end
    end

    event = AuditEvent(
        event_id,
        timestamp,
        event_type,
        user_id,
        user_email,
        user_ip,
        user_agent,
        resource_type,
        resource_id,
        action,
        result,
        details,
        unique(compliance_tags),
        retention_until
    )

    push!(audit_log.events, event)

    # Write to persistent storage (simplified)
    if !isempty(audit_log.storage_path)
        write_event_to_file(audit_log.storage_path, event)
    end

    return event_id
end

"""
Write audit event to file
"""
function write_event_to_file(storage_path::String, event::AuditEvent)
    # Create directory if it doesn't exist
    if !isdir(storage_path)
        mkpath(storage_path)
    end

    # Daily log files
    date_str = Dates.format(event.timestamp, "yyyy-mm-dd")
    log_file = joinpath(storage_path, "audit_$(date_str).jsonl")

    # Convert event to JSON
    event_json = Dict(
        "id" => string(event.id),
        "timestamp" => string(event.timestamp),
        "event_type" => string(event.event_type),
        "user_id" => event.user_id,
        "user_email" => event.user_email,
        "user_ip" => event.user_ip,
        "resource_type" => event.resource_type,
        "resource_id" => event.resource_id,
        "action" => event.action,
        "result" => event.result,
        "details" => event.details,
        "compliance_tags" => [string(tag) for tag in event.compliance_tags]
    )

    open(log_file, "a") do f
        println(f, JSON3.write(event_json))
    end
end

"""
Query audit log
"""
function query_events(
    audit_log::AuditLog;
    user_id::Union{String, Nothing}=nothing,
    event_type::Union{AuditEventType, Nothing}=nothing,
    resource_type::Union{String, Nothing}=nothing,
    start_date::Union{DateTime, Nothing}=nothing,
    end_date::Union{DateTime, Nothing}=nothing,
    result::Union{String, Nothing}=nothing,
    limit::Int=1000
)::Vector{AuditEvent}

    filtered = audit_log.events

    if !isnothing(user_id)
        filtered = filter(e -> e.user_id == user_id, filtered)
    end

    if !isnothing(event_type)
        filtered = filter(e -> e.event_type == event_type, filtered)
    end

    if !isnothing(resource_type)
        filtered = filter(e -> e.resource_type == resource_type, filtered)
    end

    if !isnothing(start_date)
        filtered = filter(e -> e.timestamp >= start_date, filtered)
    end

    if !isnothing(end_date)
        filtered = filter(e -> e.timestamp <= end_date, filtered)
    end

    if !isnothing(result)
        filtered = filter(e -> e.result == result, filtered)
    end

    # Sort by timestamp descending
    sorted = sort(filtered, by=e -> e.timestamp, rev=true)

    return sorted[1:min(limit, length(sorted))]
end

"""
Generate compliance report
"""
function generate_compliance_report(
    audit_log::AuditLog,
    framework::ComplianceFramework,
    start_date::DateTime,
    end_date::DateTime
)::Dict{String, Any}

    # Filter events by compliance tag
    relevant_events = filter(e -> framework in e.compliance_tags && start_date <= e.timestamp <= end_date, audit_log.events)

    # Count by event type
    event_counts = Dict{AuditEventType, Int}()
    for event in relevant_events
        event_counts[event.event_type] = get(event_counts, event.event_type, 0) + 1
    end

    # Count failures
    failed_events = filter(e -> e.result == "failure", relevant_events)
    failure_rate = length(relevant_events) > 0 ? length(failed_events) / length(relevant_events) : 0.0

    # Unique users
    unique_users = unique([e.user_id for e in relevant_events])

    # Data access summary
    data_access_events = filter(e -> e.event_type in [DATA_ACCESS, DATA_EXPORT, DATA_MODIFICATION], relevant_events)

    return Dict(
        "framework" => string(framework),
        "period" => Dict(
            "start" => string(start_date),
            "end" => string(end_date)
        ),
        "total_events" => length(relevant_events),
        "unique_users" => length(unique_users),
        "event_counts" => Dict(string(k) => v for (k, v) in event_counts),
        "failure_rate" => failure_rate,
        "data_access_count" => length(data_access_events),
        "compliance_status" => failure_rate < 0.01 ? "COMPLIANT" : "REVIEW_REQUIRED"
    )
end

"""
Export audit log for compliance review
"""
function export_audit_log(
    audit_log::AuditLog,
    output_file::String;
    start_date::Union{DateTime, Nothing}=nothing,
    end_date::Union{DateTime, Nothing}=nothing
)::Int

    events_to_export = query_events(
        audit_log,
        start_date=start_date,
        end_date=end_date,
        limit=typemax(Int)
    )

    open(output_file, "w") do f
        # Write header
        println(f, "Timestamp,Event Type,User ID,User Email,Resource Type,Resource ID,Action,Result,IP Address")

        for event in events_to_export
            println(f, "$(event.timestamp),$(event.event_type),$(event.user_id),$(event.user_email),$(event.resource_type),$(event.resource_id),$(event.action),$(event.result),$(event.user_ip)")
        end
    end

    return length(events_to_export)
end

"""
Clean up expired audit events (per retention policy)
"""
function cleanup_expired_events!(audit_log::AuditLog)::Int
    current_time = now(Dates.UTC)

    initial_count = length(audit_log.events)
    filter!(e -> e.retention_until > current_time, audit_log.events)
    removed_count = initial_count - length(audit_log.events)

    if removed_count > 0
        @info "Cleaned up $removed_count expired audit events"
    end

    return removed_count
end

export AuditEventType, ComplianceFramework, AuditEvent, AuditLog
export log_event!, query_events, generate_compliance_report, export_audit_log, cleanup_expired_events!
