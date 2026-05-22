# SPDX-License-Identifier: MPL-2.0
"""
SLA Monitoring and Alerting - v5.0

Track uptime, response times, and service level agreements with alerting.
"""

using Dates, Statistics

@enum AlertSeverity begin
    INFO
    WARNING
    CRITICAL
end

@enum SLAMetric begin
    UPTIME
    RESPONSE_TIME
    ERROR_RATE
    THROUGHPUT
    AVAILABILITY
end

struct SLATarget
    metric::SLAMetric
    target_value::Float64
    threshold_warning::Float64
    threshold_critical::Float64
    measurement_window::Period
end

struct SLAMeasurement
    metric::SLAMetric
    value::Float64
    timestamp::DateTime
    meets_target::Bool
end

struct SLAAlert
    id::String
    severity::AlertSeverity
    metric::SLAMetric
    message::String
    current_value::Float64
    target_value::Float64
    timestamp::DateTime
    acknowledged::Bool
end

struct SLAMonitor
    targets::Dict{SLAMetric, SLATarget}
    measurements::Vector{SLAMeasurement}
    alerts::Vector{SLAAlert}
    alert_callbacks::Vector{Function}
end

"""
Initialize SLA monitor with default targets
"""
function SLAMonitor()
    targets = Dict(
        UPTIME => SLATarget(UPTIME, 99.9, 99.5, 99.0, Hour(24)),
        RESPONSE_TIME => SLATarget(RESPONSE_TIME, 200.0, 500.0, 1000.0, Minute(5)),  # ms
        ERROR_RATE => SLATarget(ERROR_RATE, 0.1, 1.0, 5.0, Minute(15)),  # %
        THROUGHPUT => SLATarget(THROUGHPUT, 1000.0, 800.0, 500.0, Minute(5)),  # req/min
        AVAILABILITY => SLATarget(AVAILABILITY, 99.99, 99.9, 99.5, Hour(24))  # %
    )

    return SLAMonitor(targets, SLAMeasurement[], SLAAlert[], Function[])
end

"""
Record SLA measurement
"""
function record_measurement!(
    monitor::SLAMonitor,
    metric::SLAMetric,
    value::Float64
)::Nothing

    target = monitor.targets[metric]

    # Determine if target is met (depends on metric type)
    meets_target = if metric in [UPTIME, THROUGHPUT, AVAILABILITY]
        value >= target.target_value
    else  # Lower is better for response time and error rate
        value <= target.target_value
    end

    measurement = SLAMeasurement(metric, value, now(), meets_target)
    push!(monitor.measurements, measurement)

    # Check thresholds and generate alerts
    check_thresholds!(monitor, metric, value, target)

    return nothing
end

"""
Check thresholds and generate alerts
"""
function check_thresholds!(
    monitor::SLAMonitor,
    metric::SLAMetric,
    value::Float64,
    target::SLATarget
)::Nothing

    severity = nothing
    message = ""

    if metric in [UPTIME, THROUGHPUT, AVAILABILITY]
        # Higher is better
        if value < target.threshold_critical
            severity = CRITICAL
            message = "$(metric) at $(round(value, digits=2)) is below critical threshold $(target.threshold_critical)"
        elseif value < target.threshold_warning
            severity = WARNING
            message = "$(metric) at $(round(value, digits=2)) is below warning threshold $(target.threshold_warning)"
        end
    else
        # Lower is better
        if value > target.threshold_critical
            severity = CRITICAL
            message = "$(metric) at $(round(value, digits=2)) exceeds critical threshold $(target.threshold_critical)"
        elseif value > target.threshold_warning
            severity = WARNING
            message = "$(metric) at $(round(value, digits=2)) exceeds warning threshold $(target.threshold_warning)"
        end
    end

    if !isnothing(severity)
        alert = SLAAlert(
            string(hash(string(now(), metric))),
            severity,
            metric,
            message,
            value,
            target.target_value,
            now(),
            false
        )
        push!(monitor.alerts, alert)

        # Trigger callbacks
        for callback in monitor.alert_callbacks
            try
                callback(alert)
            catch e
                @error "Alert callback failed" exception=e
            end
        end
    end

    return nothing
end

"""
Calculate SLA compliance over time window
"""
function calculate_compliance(
    monitor::SLAMonitor,
    metric::SLAMetric,
    window::Period=Hour(24)
)::Float64

    cutoff_time = now() - window
    recent_measurements = filter(m -> m.metric == metric && m.timestamp >= cutoff_time, monitor.measurements)

    if isempty(recent_measurements)
        return 100.0
    end

    met_count = count(m -> m.meets_target, recent_measurements)
    return (met_count / length(recent_measurements)) * 100.0
end

"""
Get SLA summary for all metrics
"""
function get_sla_summary(monitor::SLAMonitor, window::Period=Hour(24))::Dict{String, Any}
    summary = Dict{String, Any}()

    for (metric, target) in monitor.targets
        cutoff_time = now() - window
        recent_measurements = filter(m -> m.metric == metric && m.timestamp >= cutoff_time, monitor.measurements)

        if isempty(recent_measurements)
            summary[string(metric)] = Dict(
                "status" => "NO_DATA",
                "current_value" => nothing,
                "target" => target.target_value,
                "compliance" => 0.0
            )
            continue
        end

        current_value = mean([m.value for m in recent_measurements])
        compliance = calculate_compliance(monitor, metric, window)

        status = if compliance >= 99.0
            "MEETING_SLA"
        elseif compliance >= 95.0
            "AT_RISK"
        else
            "BREACH"
        end

        summary[string(metric)] = Dict(
            "status" => status,
            "current_value" => round(current_value, digits=2),
            "target" => target.target_value,
            "compliance" => round(compliance, digits=2),
            "measurements" => length(recent_measurements)
        )
    end

    # Active alerts
    active_alerts = filter(a -> !a.acknowledged, monitor.alerts)
    summary["active_alerts"] = Dict(
        "total" => length(active_alerts),
        "critical" => count(a -> a.severity == CRITICAL, active_alerts),
        "warning" => count(a -> a.severity == WARNING, active_alerts),
        "info" => count(a -> a.severity == INFO, active_alerts)
    )

    return summary
end

"""
Register alert callback
"""
function register_alert_callback!(monitor::SLAMonitor, callback::Function)::Nothing
    push!(monitor.alert_callbacks, callback)
    return nothing
end

"""
Acknowledge alert
"""
function acknowledge_alert!(monitor::SLAMonitor, alert_id::String)::Bool
    idx = findfirst(a -> a.id == alert_id, monitor.alerts)
    if !isnothing(idx)
        # Create new alert with acknowledged=true (since structs are immutable)
        old_alert = monitor.alerts[idx]
        monitor.alerts[idx] = SLAAlert(
            old_alert.id,
            old_alert.severity,
            old_alert.metric,
            old_alert.message,
            old_alert.current_value,
            old_alert.target_value,
            old_alert.timestamp,
            true
        )
        return true
    end
    return false
end

"""
Generate SLA report
"""
function generate_sla_report(monitor::SLAMonitor, window::Period=Day(7))::String
    summary = get_sla_summary(monitor, window)

    report = """
    # SLA Monitoring Report

    **Generated:** $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))
    **Time Window:** $(window)

    ## Overall Status

    """

    # Count statuses
    meeting = count(v -> isa(v, Dict) && get(v, "status", "") == "MEETING_SLA", values(summary))
    at_risk = count(v -> isa(v, Dict) && get(v, "status", "") == "AT_RISK", values(summary))
    breach = count(v -> isa(v, Dict) && get(v, "status", "") == "BREACH", values(summary))

    overall_status = if breach > 0
        "🔴 SLA BREACH"
    elseif at_risk > 0
        "🟡 AT RISK"
    else
        "✅ ALL TARGETS MET"
    end

    report *= "**Status:** $overall_status\n\n"

    report *= """
    ## Metrics

    | Metric | Status | Current | Target | Compliance |
    |--------|--------|---------|--------|------------|
    """

    for (metric_name, data) in summary
        if metric_name == "active_alerts"
            continue
        end

        status_emoji = if data["status"] == "MEETING_SLA"
            "✅"
        elseif data["status"] == "AT_RISK"
            "🟡"
        elseif data["status"] == "BREACH"
            "🔴"
        else
            "⚪"
        end

        current = isnothing(data["current_value"]) ? "N/A" : string(round(data["current_value"], digits=2))
        compliance = data["compliance"]

        report *= "| $metric_name | $status_emoji $(data["status"]) | $current | $(data["target"]) | $(round(compliance, digits=1))% |\n"
    end

    report *= """

    ## Active Alerts

    """

    if haskey(summary, "active_alerts")
        alert_summary = summary["active_alerts"]
        report *= """
        - **Total:** $(alert_summary["total"])
        - **Critical:** $(alert_summary["critical"])
        - **Warning:** $(alert_summary["warning"])
        - **Info:** $(alert_summary["info"])

        """

        active_alerts = filter(a -> !a.acknowledged, monitor.alerts)
        if !isempty(active_alerts)
            report *= "### Recent Alerts\n\n"
            for alert in active_alerts[max(1, end-9):end]
                severity_emoji = alert.severity == CRITICAL ? "🔴" : alert.severity == WARNING ? "🟡" : "🔵"
                report *= "- $severity_emoji **$(alert.metric)**: $(alert.message) ($(Dates.format(alert.timestamp, "mm-dd HH:MM")))\n"
            end
        end
    end

    report *= """

    ## Recommendations

    """

    if breach > 0
        report *= "- **URGENT:** Address SLA breaches immediately\n"
        report *= "- Review capacity and scaling policies\n"
        report *= "- Investigate root causes of performance degradation\n"
    elseif at_risk > 0
        report *= "- Monitor at-risk metrics closely\n"
        report *= "- Consider preventive scaling\n"
        report *= "- Review recent changes that may impact performance\n"
    else
        report *= "- All SLAs are being met\n"
        report *= "- Continue monitoring and maintaining current practices\n"
    end

    return report
end

export AlertSeverity, SLAMetric, SLATarget, SLAMeasurement, SLAAlert, SLAMonitor
export record_measurement!, calculate_compliance, get_sla_summary
export register_alert_callback!, acknowledge_alert!, generate_sla_report
