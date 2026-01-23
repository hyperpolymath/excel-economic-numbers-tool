# SPDX-License-Identifier: PMPL-1.0-or-later
"""
Data Governance Framework - v5.0

Data lineage, data quality, PII detection, classification, and retention policies.
"""

using Dates, UUIDs

@enum DataClassification begin
    PUBLIC
    INTERNAL
    CONFIDENTIAL
    RESTRICTED
end

@enum PIIType begin
    EMAIL
    PHONE_NUMBER
    SSN
    CREDIT_CARD
    IP_ADDRESS
    ADDRESS
    NAME
    DATE_OF_BIRTH
end

struct DataLineage
    dataset_id::UUID
    source::String
    transformations::Vector{String}
    created_at::DateTime
    created_by::String
    parent_datasets::Vector{UUID}
    metadata::Dict{String, Any}
end

struct DataQualityMetrics
    completeness::Float64  # % of non-null values
    accuracy::Float64  # % of values meeting validation rules
    consistency::Float64  # % of values consistent across sources
    timeliness::Float64  # Freshness score (0-1)
    uniqueness::Float64  # % of unique values where expected
    validity::Float64  # % of values in valid format
end

struct PIIDetection
    field_name::String
    pii_type::PIIType
    confidence::Float64
    sample_value::String  # Masked
    occurrences::Int
end

struct DataGovernancePolicy
    classification::DataClassification
    retention_days::Int
    encryption_required::Bool
    pii_fields::Vector{String}
    allowed_regions::Vector{String}
    access_restrictions::Dict{String, Vector{String}}
    audit_required::Bool
end

struct GovernedDataset
    id::UUID
    name::String
    classification::DataClassification
    policy::DataGovernancePolicy
    lineage::DataLineage
    quality_metrics::DataQualityMetrics
    pii_detections::Vector{PIIDetection}
    last_assessed::DateTime
end

"""
Detect PII in data fields
"""
function detect_pii(data::Vector{String}, field_name::String)::Vector{PIIDetection}
    detections = PIIDetection[]

    # Email pattern
    email_pattern = r"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"
    email_matches = filter(v -> occursin(email_pattern, v), data)
    if !isempty(email_matches)
        push!(detections, PIIDetection(
            field_name,
            EMAIL,
            0.95,
            mask_value(email_matches[1]),
            length(email_matches)
        ))
    end

    # Phone number pattern
    phone_pattern = r"\d{3}[-.]?\d{3}[-.]?\d{4}"
    phone_matches = filter(v -> occursin(phone_pattern, v), data)
    if !isempty(phone_matches)
        push!(detections, PIIDetection(
            field_name,
            PHONE_NUMBER,
            0.90,
            mask_value(phone_matches[1]),
            length(phone_matches)
        ))
    end

    # SSN pattern
    ssn_pattern = r"\d{3}-\d{2}-\d{4}"
    ssn_matches = filter(v -> occursin(ssn_pattern, v), data)
    if !isempty(ssn_matches)
        push!(detections, PIIDetection(
            field_name,
            SSN,
            0.95,
            "***-**-****",
            length(ssn_matches)
        ))
    end

    # Credit card pattern (simplified)
    cc_pattern = r"\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}"
    cc_matches = filter(v -> occursin(cc_pattern, v), data)
    if !isempty(cc_matches)
        push!(detections, PIIDetection(
            field_name,
            CREDIT_CARD,
            0.90,
            "**** **** **** ****",
            length(cc_matches)
        ))
    end

    # IP address pattern
    ip_pattern = r"\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b"
    ip_matches = filter(v -> occursin(ip_pattern, v), data)
    if !isempty(ip_matches)
        push!(detections, PIIDetection(
            field_name,
            IP_ADDRESS,
            0.85,
            mask_value(ip_matches[1]),
            length(ip_matches)
        ))
    end

    return detections
end

"""
Mask sensitive values
"""
function mask_value(value::String)::String
    if length(value) <= 4
        return repeat("*", length(value))
    end

    visible_chars = 2
    masked_length = length(value) - (2 * visible_chars)

    return value[1:visible_chars] * repeat("*", masked_length) * value[end-visible_chars+1:end]
end

"""
Calculate data quality metrics
"""
function assess_data_quality(
    data::Vector{Union{Missing, T}},
    validation_func::Union{Function, Nothing}=nothing
) where T

    n = length(data)
    if n == 0
        return DataQualityMetrics(0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
    end

    # Completeness
    non_missing = count(!ismissing, data)
    completeness = non_missing / n

    # Accuracy (if validation function provided)
    accuracy = if !isnothing(validation_func)
        valid_count = count(v -> !ismissing(v) && validation_func(v), data)
        valid_count / non_missing
    else
        1.0  # Assume accurate if no validation
    end

    # Uniqueness (for columns that should be unique)
    non_missing_data = filter(!ismissing, data)
    uniqueness = length(unique(non_missing_data)) / max(length(non_missing_data), 1)

    # Timeliness (simplified - assume recent data is timely)
    timeliness = 1.0

    # Consistency and validity (simplified)
    consistency = 1.0
    validity = accuracy

    return DataQualityMetrics(
        completeness,
        accuracy,
        consistency,
        timeliness,
        uniqueness,
        validity
    )
end

"""
Create data lineage record
"""
function create_lineage(
    dataset_id::UUID,
    source::String,
    transformations::Vector{String},
    created_by::String;
    parent_datasets::Vector{UUID}=UUID[],
    metadata::Dict{String, Any}=Dict{String, Any}()
)::DataLineage

    return DataLineage(
        dataset_id,
        source,
        transformations,
        now(),
        created_by,
        parent_datasets,
        metadata
    )
end

"""
Define governance policy
"""
function create_governance_policy(
    classification::DataClassification;
    retention_days::Int=365,
    encryption_required::Bool=true,
    pii_fields::Vector{String}=String[],
    allowed_regions::Vector{String}=["US", "EU"],
    access_restrictions::Dict{String, Vector{String}}=Dict{String, Vector{String}}(),
    audit_required::Bool=true
)::DataGovernancePolicy

    return DataGovernancePolicy(
        classification,
        retention_days,
        encryption_required,
        pii_fields,
        allowed_regions,
        access_restrictions,
        audit_required
    )
end

"""
Apply governance policy to dataset
"""
function govern_dataset(
    name::String,
    classification::DataClassification,
    policy::DataGovernancePolicy,
    lineage::DataLineage,
    data_sample::Vector{Vector{String}},
    field_names::Vector{String}
)::GovernedDataset

    # Detect PII in all fields
    pii_detections = PIIDetection[]
    for (i, field) in enumerate(field_names)
        if i <= length(data_sample)
            detections = detect_pii(data_sample[i], field)
            append!(pii_detections, detections)
        end
    end

    # Calculate quality metrics (using first field as example)
    quality_metrics = if !isempty(data_sample)
        # Convert to Union{Missing, String} for demonstration
        sample_data = Union{Missing, String}[v for v in data_sample[1]]
        assess_data_quality(sample_data)
    else
        DataQualityMetrics(0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
    end

    return GovernedDataset(
        lineage.dataset_id,
        name,
        classification,
        policy,
        lineage,
        quality_metrics,
        pii_detections,
        now()
    )
end

"""
Check if data access is allowed
"""
function check_data_access(
    dataset::GovernedDataset,
    user_role::String,
    user_region::String
)::Tuple{Bool, String}

    # Check region restrictions
    if !isempty(dataset.policy.allowed_regions) && !(user_region in dataset.policy.allowed_regions)
        return (false, "Access denied: User region not in allowed regions")
    end

    # Check role-based restrictions
    if haskey(dataset.policy.access_restrictions, string(dataset.classification))
        allowed_roles = dataset.policy.access_restrictions[string(dataset.classification)]
        if !isempty(allowed_roles) && !(user_role in allowed_roles)
            return (false, "Access denied: User role lacks required permissions")
        end
    end

    # Check if PII access requires special permission
    if !isempty(dataset.pii_detections) && user_role != "DataProtectionOfficer"
        if dataset.classification in [CONFIDENTIAL, RESTRICTED]
            return (false, "Access denied: PII data requires elevated permissions")
        end
    end

    return (true, "Access granted")
end

"""
Generate governance report
"""
function generate_governance_report(dataset::GovernedDataset)::String
    report = """
    # Data Governance Report: $(dataset.name)

    **Generated:** $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))

    ## Classification

    **Level:** $(dataset.classification)
    **Retention Period:** $(dataset.policy.retention_days) days
    **Encryption Required:** $(dataset.policy.encryption_required)
    **Audit Required:** $(dataset.policy.audit_required)

    ## Data Quality Metrics

    | Metric | Score |
    |--------|-------|
    | Completeness | $(round(dataset.quality_metrics.completeness * 100, digits=1))% |
    | Accuracy | $(round(dataset.quality_metrics.accuracy * 100, digits=1))% |
    | Consistency | $(round(dataset.quality_metrics.consistency * 100, digits=1))% |
    | Timeliness | $(round(dataset.quality_metrics.timeliness * 100, digits=1))% |
    | Uniqueness | $(round(dataset.quality_metrics.uniqueness * 100, digits=1))% |
    | Validity | $(round(dataset.quality_metrics.validity * 100, digits=1))% |

    **Overall Score:** $(round(mean([dataset.quality_metrics.completeness, dataset.quality_metrics.accuracy, dataset.quality_metrics.consistency, dataset.quality_metrics.timeliness, dataset.quality_metrics.uniqueness, dataset.quality_metrics.validity]) * 100, digits=1))%

    ## PII Detection

    """

    if isempty(dataset.pii_detections)
        report *= "No PII detected.\n\n"
    else
        report *= "**$(length(dataset.pii_detections)) PII field(s) detected:**\n\n"
        for detection in dataset.pii_detections
            report *= "- **$(detection.field_name)**: $(detection.pii_type) ($(round(detection.confidence * 100, digits=1))% confidence, $(detection.occurrences) occurrences)\n"
        end
        report *= "\n"
    end

    report *= """
    ## Data Lineage

    **Source:** $(dataset.lineage.source)
    **Created By:** $(dataset.lineage.created_by)
    **Created At:** $(dataset.lineage.created_at)
    **Parent Datasets:** $(length(dataset.lineage.parent_datasets))

    **Transformations:**
    """

    for (i, transform) in enumerate(dataset.lineage.transformations)
        report *= "\n$(i). $transform"
    end

    report *= """

    ## Compliance

    **Last Assessment:** $(dataset.last_assessed)
    **Status:** $(length(dataset.pii_detections) > 0 ? "⚠️ Contains PII - Extra protection required" : "✅ No PII detected")
    """

    return report
end

export DataClassification, PIIType, DataLineage, DataQualityMetrics, PIIDetection
export DataGovernancePolicy, GovernedDataset
export detect_pii, assess_data_quality, create_lineage, create_governance_policy
export govern_dataset, check_data_access, generate_governance_report
