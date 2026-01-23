# SPDX-License-Identifier: PMPL-1.0-or-later
"""
Operational Transformation for Real-Time Co-Editing - v8.0

Conflict-free collaborative editing using OT algorithm.
"""

using UUIDs, Dates

@enum OperationType INSERT DELETE RETAIN

struct Operation
    type::OperationType
    position::Int
    content::String
    length::Int
end

struct TransformedOp
    operation::Operation
    client_op::Operation
end

"""
Create insert operation
"""
function insert_op(position::Int, content::String)::Operation
    return Operation(INSERT, position, content, length(content))
end

"""
Create delete operation
"""
function delete_op(position::Int, length::Int)::Operation
    return Operation(DELETE, position, "", length)
end

"""
Create retain operation (no-op to advance cursor)
"""
function retain_op(length::Int)::Operation
    return Operation(RETAIN, 0, "", length)
end

"""
Transform two operations against each other (OT core algorithm)
"""
function transform(op1::Operation, op2::Operation, op1_is_left::Bool=true)::Tuple{Operation, Operation}
    # INSERT vs INSERT
    if op1.type == INSERT && op2.type == INSERT
        if op1.position < op2.position || (op1.position == op2.position && op1_is_left)
            # op1 comes before op2
            new_op1 = op1
            new_op2 = Operation(op2.type, op2.position + op1.length, op2.content, op2.length)
            return (new_op1, new_op2)
        else
            # op2 comes before op1
            new_op1 = Operation(op1.type, op1.position + op2.length, op1.content, op1.length)
            new_op2 = op2
            return (new_op1, new_op2)
        end
    end

    # INSERT vs DELETE
    if op1.type == INSERT && op2.type == DELETE
        if op1.position <= op2.position
            new_op1 = op1
            new_op2 = Operation(op2.type, op2.position + op1.length, op2.content, op2.length)
            return (new_op1, new_op2)
        elseif op1.position >= op2.position + op2.length
            new_op1 = Operation(op1.type, op1.position - op2.length, op1.content, op1.length)
            new_op2 = op2
            return (new_op1, new_op2)
        else
            # Insert is within delete range - complex case
            new_op1 = Operation(op1.type, op2.position, op1.content, op1.length)
            new_op2 = Operation(op2.type, op2.position, op2.content, op2.length)
            return (new_op1, new_op2)
        end
    end

    # DELETE vs INSERT
    if op1.type == DELETE && op2.type == INSERT
        if op2.position <= op1.position
            new_op1 = Operation(op1.type, op1.position + op2.length, op1.content, op1.length)
            new_op2 = op2
            return (new_op1, new_op2)
        elseif op2.position >= op1.position + op1.length
            new_op1 = op1
            new_op2 = Operation(op2.type, op2.position - op1.length, op2.content, op2.length)
            return (new_op1, new_op2)
        else
            new_op1 = op1
            new_op2 = Operation(op2.type, op1.position, op2.content, op2.length)
            return (new_op1, new_op2)
        end
    end

    # DELETE vs DELETE
    if op1.type == DELETE && op2.type == DELETE
        if op1.position + op1.length <= op2.position
            new_op1 = op1
            new_op2 = Operation(op2.type, op2.position - op1.length, op2.content, op2.length)
            return (new_op1, new_op2)
        elseif op2.position + op2.length <= op1.position
            new_op1 = Operation(op1.type, op1.position - op2.length, op1.content, op1.length)
            new_op2 = op2
            return (new_op1, new_op2)
        else
            # Overlapping deletes - need to split
            if op1.position <= op2.position
                overlap_start = op2.position
                overlap_end = min(op1.position + op1.length, op2.position + op2.length)
                overlap_len = overlap_end - overlap_start

                new_op1 = Operation(op1.type, op1.position, op1.content, op1.length - overlap_len)
                new_op2 = Operation(op2.type, op1.position + new_op1.length, op2.content, op2.length - overlap_len)
                return (new_op1, new_op2)
            else
                overlap_start = op1.position
                overlap_end = min(op1.position + op1.length, op2.position + op2.length)
                overlap_len = overlap_end - overlap_start

                new_op1 = Operation(op1.type, op2.position, op1.content, op1.length - overlap_len)
                new_op2 = Operation(op2.type, op2.position, op2.content, op2.length - overlap_len)
                return (new_op1, new_op2)
            end
        end
    end

    # Default: no transformation needed
    return (op1, op2)
end

"""
Apply operation to document
"""
function apply_operation(document::String, op::Operation)::String
    if op.type == INSERT
        before = document[1:min(op.position, end)]
        after = document[min(op.position + 1, end):end]
        return before * op.content * after
    elseif op.type == DELETE
        before = document[1:min(op.position, end)]
        after = document[min(op.position + op.length + 1, end):end]
        return before * after
    else
        return document
    end
end

"""
Compose two operations into one
"""
function compose(op1::Operation, op2::Operation)::Vector{Operation}
    # Simplified composition - in production, handle all cases
    if op1.type == INSERT && op2.type == INSERT
        if op1.position + op1.length == op2.position
            # Sequential inserts - merge
            return [Operation(INSERT, op1.position, op1.content * op2.content, op1.length + op2.length)]
        end
    end

    return [op1, op2]
end

"""
Session state for collaborative editing
"""
mutable struct CollaborationSession
    session_id::UUID
    document_id::String
    participants::Dict{String, DateTime}
    operations::Vector{Tuple{String, Operation, DateTime}}
    current_document::String
    revision::Int
end

function CollaborationSession(document_id::String, initial_content::String="")
    return CollaborationSession(
        uuid4(),
        document_id,
        Dict{String, DateTime}(),
        Tuple{String, Operation, DateTime}[],
        initial_content,
        0
    )
end

"""
Add participant to session
"""
function join_session!(session::CollaborationSession, user_id::String)::Nothing
    session.participants[user_id] = now()
    @info "User $user_id joined session $(session.session_id)"
    return nothing
end

"""
Remove participant from session
"""
function leave_session!(session::CollaborationSession, user_id::String)::Nothing
    delete!(session.participants, user_id)
    @info "User $user_id left session $(session.session_id)"
    return nothing
end

"""
Submit operation to session
"""
function submit_operation!(
    session::CollaborationSession,
    user_id::String,
    op::Operation,
    base_revision::Int
)::Tuple{Operation, Int}

    # Transform against all operations since base revision
    transformed_op = op
    for (_, pending_op, _) in session.operations[base_revision+1:end]
        (transformed_op, _) = transform(transformed_op, pending_op, true)
    end

    # Apply to document
    session.current_document = apply_operation(session.current_document, transformed_op)

    # Record operation
    push!(session.operations, (user_id, transformed_op, now()))
    session.revision += 1

    # Update participant timestamp
    session.participants[user_id] = now()

    return (transformed_op, session.revision)
end

"""
Get operations since revision
"""
function get_operations_since(
    session::CollaborationSession,
    since_revision::Int
)::Vector{Tuple{String, Operation, DateTime}}

    if since_revision >= session.revision
        return Tuple{String, Operation, DateTime}[]
    end

    return session.operations[since_revision+1:end]
end

"""
Get current document state
"""
function get_document_state(session::CollaborationSession)::Tuple{String, Int}
    return (session.current_document, session.revision)
end

"""
Get active participants
"""
function get_active_participants(
    session::CollaborationSession,
    activity_window::Period=Minute(5)
)::Vector{String}

    cutoff = now() - activity_window
    return [user_id for (user_id, last_seen) in session.participants if last_seen >= cutoff]
end

export OperationType, Operation, TransformedOp
export insert_op, delete_op, retain_op, transform, apply_operation, compose
export CollaborationSession, join_session!, leave_session!, submit_operation!
export get_operations_since, get_document_state, get_active_participants
