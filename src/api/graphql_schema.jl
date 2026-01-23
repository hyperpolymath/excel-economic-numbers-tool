# SPDX-License-Identifier: PMPL-1.0-or-later
"""
GraphQL API - v9.0

Modern GraphQL API for flexible data querying.
"""

using GraphQLite

"""
GraphQL Schema Definition
"""
const SCHEMA = gql"""
schema {
  query: Query
  mutation: Mutation
  subscription: Subscription
}

# Root Query Type
type Query {
  # Data Sources
  sources(filter: SourceFilter): [DataSource!]!
  source(id: ID!): DataSource

  # Series
  series(id: ID!): Series
  searchSeries(
    query: String!
    source: String
    limit: Int = 10
    offset: Int = 0
  ): SeriesSearchResult!

  # Multiple series
  seriesBatch(ids: [ID!]!): [Series!]!

  # User
  me: User!
  user(id: ID!): User

  # Workspaces
  workspaces: [Workspace!]!
  workspace(id: ID!): Workspace

  # Dashboards
  dashboards(workspaceId: ID): [Dashboard!]!
  dashboard(id: ID!): Dashboard
}

# Mutations
type Mutation {
  # Workspaces
  createWorkspace(input: CreateWorkspaceInput!): Workspace!
  updateWorkspace(id: ID!, input: UpdateWorkspaceInput!): Workspace!
  deleteWorkspace(id: ID!): Boolean!

  # Dashboards
  createDashboard(input: CreateDashboardInput!): Dashboard!
  updateDashboard(id: ID!, input: UpdateDashboardInput!): Dashboard!
  deleteDashboard(id: ID!): Boolean!

  # Comments
  addComment(input: AddCommentInput!): Comment!
  editComment(id: ID!, content: String!): Comment!
  deleteComment(id: ID!): Boolean!
  resolveComment(id: ID!): Comment!

  # Sharing
  shareResource(input: ShareResourceInput!): SharePermission!
  updateSharePermission(id: ID!, permission: Permission!): SharePermission!
  revokeSharePermission(id: ID!): Boolean!
}

# Subscriptions
type Subscription {
  # Real-time series updates
  seriesUpdated(id: ID!): Series!

  # Collaboration
  documentChanged(documentId: ID!): DocumentChange!
  commentAdded(documentId: ID!): Comment!
  userPresence(workspaceId: ID!): UserPresence!
}

# Data Source
type DataSource {
  id: ID!
  name: String!
  description: String
  url: String
  seriesCount: Int!
  categories: [String!]!
  coverage: String
  lastUpdated: DateTime
}

input SourceFilter {
  category: String
  coverage: String
  search: String
}

# Series
type Series {
  id: ID!
  source: DataSource!
  name: String!
  description: String
  frequency: Frequency!
  units: String
  seasonalAdjustment: String
  geography: String
  startDate: Date!
  endDate: Date
  lastUpdated: DateTime
  observations(
    startDate: Date
    endDate: Date
    frequency: Frequency
    transformation: Transformation
  ): [Observation!]!
  metadata: SeriesMetadata
  relatedSeries: [Series!]!
}

type Observation {
  date: Date!
  value: Float!
}

type SeriesMetadata {
  sourceUrl: String
  license: String
  citation: String
  methodology: String
  notes: String
  tags: [String!]!
}

type SeriesSearchResult {
  results: [Series!]!
  total: Int!
  page: Int!
  perPage: Int!
}

# Transformations
enum Transformation {
  LEVELS
  PCT_CHANGE
  LOG
  DIFF
  GROWTH_RATE
  MOVING_AVERAGE
  NORMALIZE
}

# Enums
enum Frequency {
  DAILY
  WEEKLY
  MONTHLY
  QUARTERLY
  ANNUAL
}

enum Permission {
  READ
  WRITE
  ADMIN
}

# User
type User {
  id: ID!
  email: String!
  name: String!
  avatar: String
  role: UserRole!
  workspaces: [Workspace!]!
  certifications: [Certification!]!
  createdAt: DateTime!
}

enum UserRole {
  FREE
  PROFESSIONAL
  ENTERPRISE
  ADMIN
}

type Certification {
  level: String!
  issuedAt: DateTime!
  expiresAt: DateTime
}

# Workspace
type Workspace {
  id: ID!
  name: String!
  description: String
  owner: User!
  members: [WorkspaceMember!]!
  dashboards: [Dashboard!]!
  sharedLibraries: [SharedLibrary!]!
  createdAt: DateTime!
  updatedAt: DateTime!
}

type WorkspaceMember {
  user: User!
  role: WorkspaceRole!
  joinedAt: DateTime!
}

enum WorkspaceRole {
  OWNER
  ADMIN
  MEMBER
  VIEWER
}

input CreateWorkspaceInput {
  name: String!
  description: String
}

input UpdateWorkspaceInput {
  name: String
  description: String
}

# Dashboard
type Dashboard {
  id: ID!
  workspace: Workspace!
  name: String!
  description: String
  widgets: [Widget!]!
  layout: JSON!
  tags: [String!]!
  isPublic: Boolean!
  createdBy: User!
  createdAt: DateTime!
  updatedAt: DateTime!
}

type Widget {
  id: ID!
  type: WidgetType!
  title: String!
  config: JSON!
  position: WidgetPosition!
}

enum WidgetType {
  CHART
  TABLE
  METRIC
  MAP
  TEXT
}

type WidgetPosition {
  x: Int!
  y: Int!
  width: Int!
  height: Int!
}

input CreateDashboardInput {
  workspaceId: ID!
  name: String!
  description: String
  widgets: [WidgetInput!]
  layout: JSON
  tags: [String!]
  isPublic: Boolean
}

input UpdateDashboardInput {
  name: String
  description: String
  widgets: [WidgetInput!]
  layout: JSON
  tags: [String!]
  isPublic: Boolean
}

input WidgetInput {
  type: WidgetType!
  title: String!
  config: JSON!
  position: WidgetPositionInput!
}

input WidgetPositionInput {
  x: Int!
  y: Int!
  width: Int!
  height: Int!
}

# Comments
type Comment {
  id: ID!
  author: User!
  content: String!
  createdAt: DateTime!
  updatedAt: DateTime
  isResolved: Boolean!
  replies: [Comment!]!
  reactions: [Reaction!]!
}

type Reaction {
  user: User!
  type: ReactionType!
}

enum ReactionType {
  THUMBS_UP
  THUMBS_DOWN
  HEART
  CELEBRATE
  CONFUSED
}

input AddCommentInput {
  documentId: ID!
  content: String!
  parentId: ID
}

# Sharing
type SharePermission {
  id: ID!
  resource: SharedResource!
  user: User
  email: String
  permission: Permission!
  createdAt: DateTime!
}

union SharedResource = Dashboard | Workspace | SharedLibrary

input ShareResourceInput {
  resourceType: ResourceType!
  resourceId: ID!
  userEmail: String!
  permission: Permission!
}

enum ResourceType {
  DASHBOARD
  WORKSPACE
  LIBRARY
}

# Shared Library
type SharedLibrary {
  id: ID!
  workspace: Workspace!
  name: String!
  description: String
  series: [Series!]!
  createdBy: User!
  createdAt: DateTime!
}

# Collaboration
type DocumentChange {
  documentId: ID!
  userId: ID!
  operation: String!
  timestamp: DateTime!
}

type UserPresence {
  user: User!
  status: PresenceStatus!
  lastSeen: DateTime!
  cursor: CursorPosition
}

enum PresenceStatus {
  ONLINE
  AWAY
  OFFLINE
}

type CursorPosition {
  x: Int!
  y: Int!
  selection: String
}

# Scalar Types
scalar Date
scalar DateTime
scalar JSON
"""

"""
GraphQL Resolvers
"""
struct GraphQLContext
    user_id::String
    auth_token::String
    db_connection::Any
    permissions::Dict{String, Any}
end

# Query Resolvers
function resolve_sources(parent, args, context::GraphQLContext)
    # Implementation: Fetch data sources from database
    sources = [
        Dict(
            "id" => "fred",
            "name" => "Federal Reserve Economic Data",
            "description" => "800,000+ US economic time series",
            "url" => "https://fred.stlouisfed.org",
            "seriesCount" => 800000,
            "categories" => ["monetary", "fiscal", "labor", "trade"],
            "coverage" => "USA",
            "lastUpdated" => now()
        ),
        Dict(
            "id" => "worldbank",
            "name" => "World Bank Open Data",
            "description" => "Global development indicators",
            "url" => "https://data.worldbank.org",
            "seriesCount" => 16000,
            "categories" => ["development", "poverty", "education", "health"],
            "coverage" => "Global",
            "lastUpdated" => now()
        )
    ]

    # Apply filters if provided
    if haskey(args, "filter")
        filter = args["filter"]
        if haskey(filter, "category")
            sources = filter(s -> filter["category"] in s["categories"], sources)
        end
    end

    return sources
end

function resolve_series(parent, args, context::GraphQLContext)
    series_id = args["id"]

    # Mock series data
    return Dict(
        "id" => series_id,
        "source" => Dict("id" => "fred", "name" => "FRED"),
        "name" => "Real Gross Domestic Product",
        "description" => "Billions of Chained 2017 Dollars",
        "frequency" => "QUARTERLY",
        "units" => "Billions of Dollars",
        "seasonalAdjustment" => "Seasonally Adjusted",
        "geography" => "USA",
        "startDate" => Date(1947, 1, 1),
        "endDate" => Date(2025, 12, 31),
        "lastUpdated" => now(),
        "observations" => [],
        "metadata" => Dict(
            "sourceUrl" => "https://fred.stlouisfed.org/series/GDPC1",
            "license" => "Public Domain",
            "tags" => ["gdp", "output", "quarterly"]
        )
    )
end

function resolve_me(parent, args, context::GraphQLContext)
    # Return current user from context
    return Dict(
        "id" => context.user_id,
        "email" => "user@example.com",
        "name" => "John Economist",
        "role" => "PROFESSIONAL",
        "workspaces" => [],
        "certifications" => [],
        "createdAt" => now()
    )
end

# Mutation Resolvers
function resolve_create_workspace(parent, args, context::GraphQLContext)
    input = args["input"]

    workspace_id = string(uuid4())

    return Dict(
        "id" => workspace_id,
        "name" => input["name"],
        "description" => get(input, "description", nothing),
        "owner" => Dict("id" => context.user_id),
        "members" => [],
        "dashboards" => [],
        "sharedLibraries" => [],
        "createdAt" => now(),
        "updatedAt" => now()
    )
end

function resolve_add_comment(parent, args, context::GraphQLContext)
    input = args["input"]

    comment_id = string(uuid4())

    return Dict(
        "id" => comment_id,
        "author" => Dict("id" => context.user_id),
        "content" => input["content"],
        "createdAt" => now(),
        "isResolved" => false,
        "replies" => [],
        "reactions" => []
    )
end

# Subscription Resolvers
function resolve_series_updated(parent, args, context::GraphQLContext)
    series_id = args["id"]

    # Return channel for real-time updates
    # In production, this would connect to a PubSub system
    return Channel{Dict}(32)
end

export SCHEMA, GraphQLContext
export resolve_sources, resolve_series, resolve_me
export resolve_create_workspace, resolve_add_comment, resolve_series_updated
