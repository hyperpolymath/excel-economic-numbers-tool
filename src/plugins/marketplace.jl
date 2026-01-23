# SPDX-License-Identifier: PMPL-1.0-or-later
"""
Plugin Marketplace - v9.0

Discover, install, and manage community plugins.
"""

using HTTP, JSON3, UUIDs, Dates

struct MarketplaceListing
    plugin_id::UUID
    name::String
    description::String
    author::String
    version::String
    downloads::Int
    rating::Float64
    review_count::Int
    category::String
    tags::Vector{String}
    price::Float64  # 0.0 for free
    license::String
    repository_url::String
    homepage_url::String
    created_at::DateTime
    updated_at::DateTime
end

struct PluginReview
    id::UUID
    plugin_id::UUID
    author::String
    rating::Int  # 1-5
    title::String
    content::String
    helpful_count::Int
    created_at::DateTime
end

struct Marketplace
    api_url::String
    listings::Vector{MarketplaceListing}
    cache_ttl::Int  # seconds
    last_updated::DateTime
end

"""
Initialize marketplace client
"""
function Marketplace(api_url::String="https://marketplace.economictoolkit.org/api")
    return Marketplace(
        api_url,
        MarketplaceListing[],
        3600,  # 1 hour
        DateTime(2000, 1, 1)
    )
end

"""
Fetch marketplace listings
"""
function fetch_listings!(
    marketplace::Marketplace;
    category::Union{String, Nothing}=nothing,
    search::Union{String, Nothing}=nothing,
    force_refresh::Bool=false
)::Vector{MarketplaceListing}

    # Check cache
    if !force_refresh && (now() - marketplace.last_updated) < Second(marketplace.cache_ttl)
        return marketplace.listings
    end

    try
        # Build query parameters
        params = String[]
        if !isnothing(category)
            push!(params, "category=$category")
        end
        if !isnothing(search)
            push!(params, "search=$search")
        end

        query_string = isempty(params) ? "" : "?" * join(params, "&")

        # Fetch from API (mock implementation)
        # In production: response = HTTP.get("$(marketplace.api_url)/listings$query_string")

        # Mock data
        mock_listings = [
            MarketplaceListing(
                uuid4(),
                "Advanced Technical Indicators",
                "50+ technical indicators for financial analysis",
                "FinanceTools Inc",
                "1.2.0",
                15234,
                4.7,
                342,
                "Finance",
                ["finance", "trading", "indicators"],
                0.0,
                "MIT",
                "https://github.com/financetools/advanced-indicators",
                "https://financetools.com",
                DateTime(2024, 1, 15),
                DateTime(2025, 12, 1)
            ),
            MarketplaceListing(
                uuid4(),
                "Machine Learning Forecaster",
                "State-of-the-art ML models for economic forecasting",
                "DataScience Labs",
                "2.0.1",
                8912,
                4.9,
                201,
                "Machine Learning",
                ["ml", "forecasting", "ai"],
                29.99,
                "Commercial",
                "https://github.com/datasciencelab/ml-forecaster",
                "https://datasciencelab.io",
                DateTime(2023, 6, 20),
                DateTime(2025, 11, 15)
            ),
            MarketplaceListing(
                uuid4(),
                "Cryptocurrency Data Source",
                "Real-time cryptocurrency market data",
                "CryptoConnect",
                "0.9.0",
                5632,
                4.3,
                89,
                "Data Sources",
                ["crypto", "bitcoin", "ethereum", "data"],
                0.0,
                "Apache-2.0",
                "https://github.com/cryptoconnect/econ-toolkit-plugin",
                "https://cryptoconnect.io",
                DateTime(2024, 8, 1),
                DateTime(2025, 12, 20)
            )
        ]

        marketplace.listings = mock_listings

        @info "Fetched $(length(mock_listings)) plugin listings"

        return mock_listings
    catch e
        @error "Failed to fetch marketplace listings" exception=e
        return marketplace.listings
    end
end

"""
Search marketplace
"""
function search_marketplace(
    marketplace::Marketplace,
    query::String;
    min_rating::Float64=0.0,
    max_price::Float64=Inf,
    category::Union{String, Nothing}=nothing
)::Vector{MarketplaceListing}

    fetch_listings!(marketplace, category=category)

    results = marketplace.listings

    # Filter by search query
    if !isempty(query)
        query_lower = lowercase(query)
        results = filter(results) do listing
            lowercase(listing.name) |> contains(query_lower) ||
            lowercase(listing.description) |> contains(query_lower) ||
            any(tag -> contains(lowercase(tag), query_lower), listing.tags)
        end
    end

    # Filter by rating
    results = filter(l -> l.rating >= min_rating, results)

    # Filter by price
    results = filter(l -> l.price <= max_price, results)

    # Sort by relevance (downloads * rating)
    sort!(results, by=l -> l.downloads * l.rating, rev=true)

    return results
end

"""
Get plugin details
"""
function get_plugin_details(marketplace::Marketplace, plugin_id::UUID)::Union{MarketplaceListing, Nothing}
    fetch_listings!(marketplace)

    idx = findfirst(l -> l.plugin_id == plugin_id, marketplace.listings)
    return isnothing(idx) ? nothing : marketplace.listings[idx]
end

"""
Get plugin reviews
"""
function get_plugin_reviews(
    marketplace::Marketplace,
    plugin_id::UUID
)::Vector{PluginReview}

    # Mock reviews
    return [
        PluginReview(
            uuid4(),
            plugin_id,
            "john_analyst",
            5,
            "Excellent plugin!",
            "This plugin has dramatically improved our forecasting accuracy. Highly recommended!",
            42,
            DateTime(2025, 11, 1)
        ),
        PluginReview(
            uuid4(),
            plugin_id,
            "data_scientist_99",
            4,
            "Great but could use more documentation",
            "Very powerful features but the documentation could be more comprehensive.",
            18,
            DateTime(2025, 10, 15)
        )
    ]
end

"""
Install plugin from marketplace
"""
function install_plugin(
    marketplace::Marketplace,
    plugin_id::UUID;
    install_dir::String="./plugins"
)::Bool

    listing = get_plugin_details(marketplace, plugin_id)
    if isnothing(listing)
        @error "Plugin not found: $plugin_id"
        return false
    end

    try
        @info "Installing $(listing.name) v$(listing.version)..."

        # Create install directory
        if !isdir(install_dir)
            mkpath(install_dir)
        end

        plugin_dir = joinpath(install_dir, string(plugin_id))

        # Download plugin (mock implementation)
        # In production: download from repository_url

        # Create plugin directory and manifest
        mkpath(plugin_dir)

        manifest_path = joinpath(plugin_dir, "manifest.toml")
        manifest_content = """
        id = "$(plugin_id)"
        name = "$(listing.name)"
        version = "$(listing.version)"
        description = "$(listing.description)"
        author = "$(listing.author)"
        license = "$(listing.license)"
        type = "data_source"
        entry_point = "main.jl"
        """

        write(manifest_path, manifest_content)

        @info "Successfully installed $(listing.name)"
        return true
    catch e
        @error "Failed to install plugin" exception=e
        return false
    end
end

"""
Submit a plugin review
"""
function submit_review(
    marketplace::Marketplace,
    plugin_id::UUID,
    rating::Int,
    title::String,
    content::String,
    author::String
)::PluginReview

    if rating < 1 || rating > 5
        throw(ArgumentError("Rating must be between 1 and 5"))
    end

    review = PluginReview(
        uuid4(),
        plugin_id,
        author,
        rating,
        title,
        content,
        0,
        now()
    )

    # In production: POST to API
    @info "Review submitted for plugin $plugin_id"

    return review
end

"""
Get featured plugins
"""
function get_featured_plugins(marketplace::Marketplace, limit::Int=10)::Vector{MarketplaceListing}
    fetch_listings!(marketplace)

    # Sort by downloads and rating
    featured = sort(marketplace.listings, by=l -> l.downloads * l.rating, rev=true)

    return featured[1:min(limit, length(featured))]
end

"""
Get trending plugins (most downloaded recently)
"""
function get_trending_plugins(marketplace::Marketplace, limit::Int=10)::Vector{MarketplaceListing}
    fetch_listings!(marketplace)

    # Sort by recent activity (using updated_at as proxy)
    trending = sort(marketplace.listings, by=l -> l.updated_at, rev=true)

    return trending[1:min(limit, length(trending))]
end

"""
Get free plugins only
"""
function get_free_plugins(marketplace::Marketplace)::Vector{MarketplaceListing}
    fetch_listings!(marketplace)
    return filter(l -> l.price == 0.0, marketplace.listings)
end

export MarketplaceListing, PluginReview, Marketplace
export fetch_listings!, search_marketplace, get_plugin_details, get_plugin_reviews
export install_plugin, submit_review, get_featured_plugins, get_trending_plugins, get_free_plugins
