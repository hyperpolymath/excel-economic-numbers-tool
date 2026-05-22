# SPDX-License-Identifier: MPL-2.0
"""
Version Control for Economic Models - v8.0

Git-like version control for workbooks, models, and analyses.
"""

using Dates, UUIDs, SHA

struct Commit
    hash::String
    parent_hash::Union{String, Nothing}
    author::String
    email::String
    timestamp::DateTime
    message::String
    changes::Dict{String, Any}
    metadata::Dict{String, Any}
end

struct Branch
    name::String
    head_commit::String
    created_at::DateTime
    created_by::String
end

struct Repository
    id::UUID
    name::String
    description::String
    branches::Dict{String, Branch}
    commits::Dict{String, Commit}
    current_branch::String
    tags::Dict{String, String}
end

"""
Initialize a new repository
"""
function init_repository(name::String, description::String="")::Repository
    main_branch = Branch("main", "", now(), "system")

    return Repository(
        uuid4(),
        name,
        description,
        Dict("main" => main_branch),
        Dict{String, Commit}(),
        "main",
        Dict{String, String}()
    )
end

"""
Create a commit
"""
function create_commit(
    repo::Repository,
    changes::Dict{String, Any},
    message::String,
    author::String,
    email::String;
    metadata::Dict{String, Any}=Dict{String, Any}()
)::Tuple{Repository, String}

    # Get parent commit
    current_branch = repo.branches[repo.current_branch]
    parent_hash = isempty(current_branch.head_commit) ? nothing : current_branch.head_commit

    # Generate commit hash
    content = string(now(), author, email, message, hash(changes))
    commit_hash = bytes2hex(sha256(content))

    # Create commit
    commit = Commit(
        commit_hash,
        parent_hash,
        author,
        email,
        now(),
        message,
        changes,
        metadata
    )

    # Update repository
    new_commits = copy(repo.commits)
    new_commits[commit_hash] = commit

    new_branches = copy(repo.branches)
    new_branches[repo.current_branch] = Branch(
        current_branch.name,
        commit_hash,
        current_branch.created_at,
        current_branch.created_by
    )

    updated_repo = Repository(
        repo.id,
        repo.name,
        repo.description,
        new_branches,
        new_commits,
        repo.current_branch,
        repo.tags
    )

    return (updated_repo, commit_hash)
end

"""
Create a new branch
"""
function create_branch(
    repo::Repository,
    branch_name::String,
    from_commit::Union{String, Nothing}=nothing,
    created_by::String="user"
)::Repository

    # Determine base commit
    base_commit = if isnothing(from_commit)
        repo.branches[repo.current_branch].head_commit
    else
        from_commit
    end

    # Create branch
    new_branch = Branch(branch_name, base_commit, now(), created_by)

    new_branches = copy(repo.branches)
    new_branches[branch_name] = new_branch

    return Repository(
        repo.id,
        repo.name,
        repo.description,
        new_branches,
        repo.commits,
        repo.current_branch,
        repo.tags
    )
end

"""
Switch to a different branch
"""
function checkout_branch(repo::Repository, branch_name::String)::Repository
    if !haskey(repo.branches, branch_name)
        throw(ArgumentError("Branch '$branch_name' does not exist"))
    end

    return Repository(
        repo.id,
        repo.name,
        repo.description,
        repo.branches,
        repo.commits,
        branch_name,
        repo.tags
    )
end

"""
Merge branch into current branch
"""
function merge_branch(
    repo::Repository,
    source_branch::String,
    merge_message::String,
    author::String,
    email::String
)::Tuple{Repository, String}

    if !haskey(repo.branches, source_branch)
        throw(ArgumentError("Branch '$source_branch' does not exist"))
    end

    # Get commits from both branches
    target_commit = repo.branches[repo.current_branch].head_commit
    source_commit = repo.branches[source_branch].head_commit

    # Collect changes (simplified - in production, do three-way merge)
    changes = Dict{String, Any}(
        "merge" => true,
        "source_branch" => source_branch,
        "target_branch" => repo.current_branch,
        "source_commit" => source_commit,
        "target_commit" => target_commit
    )

    # Create merge commit
    return create_commit(
        repo,
        changes,
        merge_message,
        author,
        email,
        metadata=Dict("merge" => true, "parents" => [target_commit, source_commit])
    )
end

"""
Get commit history
"""
function get_history(repo::Repository, max_count::Int=100)::Vector{Commit}
    history = Commit[]

    current_commit_hash = repo.branches[repo.current_branch].head_commit
    if isempty(current_commit_hash)
        return history
    end

    count = 0
    while !isnothing(current_commit_hash) && count < max_count
        if haskey(repo.commits, current_commit_hash)
            commit = repo.commits[current_commit_hash]
            push!(history, commit)
            current_commit_hash = commit.parent_hash
            count += 1
        else
            break
        end
    end

    return history
end

"""
Create a tag
"""
function create_tag(
    repo::Repository,
    tag_name::String,
    commit_hash::Union{String, Nothing}=nothing
)::Repository

    # Default to current HEAD
    target_commit = if isnothing(commit_hash)
        repo.branches[repo.current_branch].head_commit
    else
        commit_hash
    end

    if !haskey(repo.commits, target_commit)
        throw(ArgumentError("Commit not found: $target_commit"))
    end

    new_tags = copy(repo.tags)
    new_tags[tag_name] = target_commit

    return Repository(
        repo.id,
        repo.name,
        repo.description,
        repo.branches,
        repo.commits,
        repo.current_branch,
        new_tags
    )
end

"""
Get diff between two commits
"""
function get_diff(repo::Repository, from_commit::String, to_commit::String)::Dict{String, Any}
    if !haskey(repo.commits, from_commit) || !haskey(repo.commits, to_commit)
        throw(ArgumentError("One or both commits not found"))
    end

    from = repo.commits[from_commit]
    to = repo.commits[to_commit]

    return Dict(
        "from" => from_commit,
        "to" => to_commit,
        "from_author" => from.author,
        "to_author" => to.author,
        "from_timestamp" => from.timestamp,
        "to_timestamp" => to.timestamp,
        "changes" => to.changes
    )
end

"""
Revert to a previous commit
"""
function revert_commit(
    repo::Repository,
    commit_hash::String,
    author::String,
    email::String
)::Tuple{Repository, String}

    if !haskey(repo.commits, commit_hash)
        throw(ArgumentError("Commit not found: $commit_hash"))
    end

    target_commit = repo.commits[commit_hash]

    # Create revert commit
    changes = Dict{String, Any}(
        "revert" => true,
        "reverted_commit" => commit_hash,
        "reverted_changes" => target_commit.changes
    )

    return create_commit(
        repo,
        changes,
        "Revert \"$(target_commit.message)\"",
        author,
        email,
        metadata=Dict("revert" => commit_hash)
    )
end

"""
Generate changelog
"""
function generate_changelog(repo::Repository, since_tag::Union{String, Nothing}=nothing)::String
    history = get_history(repo)

    # Find starting point
    start_index = if !isnothing(since_tag) && haskey(repo.tags, since_tag)
        tag_commit = repo.tags[since_tag]
        findfirst(c -> c.hash == tag_commit, history)
    else
        nothing
    end

    relevant_commits = if !isnothing(start_index)
        history[1:start_index-1]
    else
        history
    end

    changelog = """
    # Changelog

    Generated: $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))
    Branch: $(repo.current_branch)

    """

    for commit in relevant_commits
        changelog *= """
        ## $(commit.hash[1:8]) - $(Dates.format(commit.timestamp, "yyyy-mm-dd HH:MM"))

        **Author:** $(commit.author) <$(commit.email)>

        $(commit.message)

        ---

        """
    end

    return changelog
end

"""
Get repository status
"""
function status(repo::Repository)::Dict{String, Any}
    current_branch = repo.branches[repo.current_branch]

    return Dict(
        "repository" => repo.name,
        "current_branch" => repo.current_branch,
        "head_commit" => current_branch.head_commit,
        "total_commits" => length(repo.commits),
        "total_branches" => length(repo.branches),
        "total_tags" => length(repo.tags),
        "branches" => collect(keys(repo.branches)),
        "tags" => collect(keys(repo.tags))
    )
end

export Commit, Branch, Repository
export init_repository, create_commit, create_branch, checkout_branch, merge_branch
export get_history, create_tag, get_diff, revert_commit, generate_changelog, status
