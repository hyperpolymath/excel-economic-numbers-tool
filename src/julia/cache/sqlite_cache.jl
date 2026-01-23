"""
SQLite Cache - Persistent caching with TTL

Provides persistent caching of API responses using SQLite.
Survives restarts and supports configurable TTL per entry.
"""

using SQLite
using Dates
using SHA

"""
    SQLiteCache

Persistent cache using SQLite database with TTL support.

# Fields
- `db::SQLite.DB`: SQLite database connection
- `default_ttl::Int`: Default TTL in seconds (default: 86400 = 24 hours)
"""
struct SQLiteCache
    db::SQLite.DB
    default_ttl::Int

    function SQLiteCache(db_path::String=joinpath(homedir(), ".economic-toolkit", "cache", "data.db"); default_ttl::Int=86400)
        # Ensure directory exists
        mkpath(dirname(db_path))

        # Open database
        db = SQLite.DB(db_path)

        # Create table if not exists
        SQLite.execute(db, """
            CREATE TABLE IF NOT EXISTS cache (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                expires_at INTEGER NOT NULL,
                source TEXT,
                series_id TEXT,
                metadata TEXT
            )
        """)

        # Create index on expires_at for efficient cleanup
        SQLite.execute(db, """
            CREATE INDEX IF NOT EXISTS idx_expires_at ON cache(expires_at)
        """)

        new(db, default_ttl)
    end
end

"""
    cache_key(source::String, series_id::String, start_date::Date, end_date::Date)::String

Generate a cache key from request parameters.

# Arguments
- `source::String`: Data source name
- `series_id::String`: Series identifier
- `start_date::Date`: Start date
- `end_date::Date`: End date

# Returns
- `String`: SHA256 hash of parameters
"""
function cache_key(source::String, series_id::String, start_date::Date, end_date::Date)::String
    data = "$source|$series_id|$start_date|$end_date"
    return bytes2hex(sha256(data))
end

"""
    cache_key(source::String, query::String)::String

Generate a cache key for search queries.

# Arguments
- `source::String`: Data source name
- `query::String`: Search query

# Returns
- `String`: SHA256 hash of parameters
"""
function cache_key(source::String, query::String)::String
    data = "$source|search|$query"
    return bytes2hex(sha256(data))
end

"""
    get_cached(cache::SQLiteCache, key::String)::Union{String, Nothing}

Retrieve cached value if it exists and hasn't expired.

# Arguments
- `cache::SQLiteCache`: Cache instance
- `key::String`: Cache key

# Returns
- `Union{String, Nothing}`: Cached value or nothing if not found/expired
"""
function get_cached(cache::SQLiteCache, key::String)::Union{String, Nothing}
    now_unix = Int(floor(datetime2unix(now())))

    result = DBInterface.execute(cache.db, """
        SELECT value FROM cache
        WHERE key = ? AND expires_at > ?
    """, (key, now_unix))

    row = first(result, nothing)
    return row === nothing ? nothing : row.value
end

"""
    set_cached(cache::SQLiteCache, key::String, value::String; ttl::Union{Int, Nothing}=nothing, metadata::Dict=Dict())

Store value in cache with optional TTL.

# Arguments
- `cache::SQLiteCache`: Cache instance
- `key::String`: Cache key
- `value::String`: Value to cache (typically JSON)
- `ttl::Union{Int, Nothing}`: TTL in seconds (uses default if nothing)
- `metadata::Dict`: Additional metadata (source, series_id, etc.)
"""
function set_cached(cache::SQLiteCache, key::String, value::String; ttl::Union{Int, Nothing}=nothing, metadata::Dict=Dict())
    ttl_seconds = ttl === nothing ? cache.default_ttl : ttl
    now_unix = Int(floor(datetime2unix(now())))
    expires_at = now_unix + ttl_seconds

    source = get(metadata, "source", "")
    series_id = get(metadata, "series_id", "")
    metadata_json = JSON3.write(metadata)

    # Use INSERT OR REPLACE for upsert behavior
    SQLite.execute(cache.db, """
        INSERT OR REPLACE INTO cache (key, value, created_at, expires_at, source, series_id, metadata)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    """, (key, value, now_unix, expires_at, source, series_id, metadata_json))
end

"""
    delete_cached(cache::SQLiteCache, key::String)

Delete a specific cache entry.

# Arguments
- `cache::SQLiteCache`: Cache instance
- `key::String`: Cache key
"""
function delete_cached(cache::SQLiteCache, key::String)
    SQLite.execute(cache.db, "DELETE FROM cache WHERE key = ?", (key,))
end

"""
    clear_expired(cache::SQLiteCache)::Int

Remove expired entries from cache.

# Arguments
- `cache::SQLiteCache`: Cache instance

# Returns
- `Int`: Number of entries deleted
"""
function clear_expired(cache::SQLiteCache)::Int
    now_unix = Int(floor(datetime2unix(now())))
    result = SQLite.execute(cache.db, "DELETE FROM cache WHERE expires_at <= ?", (now_unix,))
    return SQLite.changes(cache.db)
end

"""
    clear_all(cache::SQLiteCache)::Int

Clear all cache entries.

# Arguments
- `cache::SQLiteCache`: Cache instance

# Returns
- `Int`: Number of entries deleted
"""
function clear_all(cache::SQLiteCache)::Int
    result = SQLite.execute(cache.db, "DELETE FROM cache")
    return SQLite.changes(cache.db)
end

"""
    get_stats(cache::SQLiteCache)::Dict

Get cache statistics.

# Arguments
- `cache::SQLiteCache`: Cache instance

# Returns
- `Dict`: Statistics including total entries, expired, by source, etc.
"""
function get_stats(cache::SQLiteCache)::Dict
    now_unix = Int(floor(datetime2unix(now())))

    # Total entries
    total = first(DBInterface.execute(cache.db, "SELECT COUNT(*) as count FROM cache")).count

    # Active (not expired) entries
    active = first(DBInterface.execute(cache.db, "SELECT COUNT(*) as count FROM cache WHERE expires_at > ?", (now_unix,))).count

    # Expired entries
    expired = total - active

    # Entries by source
    by_source = Dict{String, Int}()
    for row in DBInterface.execute(cache.db, "SELECT source, COUNT(*) as count FROM cache WHERE source != '' GROUP BY source")
        by_source[row.source] = row.count
    end

    # Database size
    db_size = filesize(cache.db.file)

    return Dict(
        "total" => total,
        "active" => active,
        "expired" => expired,
        "by_source" => by_source,
        "db_size_bytes" => db_size,
        "db_size_mb" => round(db_size / 1024 / 1024, digits=2)
    )
end

"""
    clear_by_source(cache::SQLiteCache, source::String)::Int

Clear all cache entries for a specific data source.

# Arguments
- `cache::SQLiteCache`: Cache instance
- `source::String`: Source name

# Returns
- `Int`: Number of entries deleted
"""
function clear_by_source(cache::SQLiteCache, source::String)::Int
    result = SQLite.execute(cache.db, "DELETE FROM cache WHERE source = ?", (source,))
    return SQLite.changes(cache.db)
end
