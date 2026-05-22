// SPDX-License-Identifier: MPL-2.0
/**
 * Custom Data Source Builder - v3.0
 *
 * Visual builder for creating custom data source connectors
 * without writing code.
 */

type httpMethod = GET | POST | PUT | DELETE

type authType =
  | NoAuth
  | APIKey({headerName: string, prefix: option<string>})
  | Bearer({tokenUrl: string})
  | OAuth2({authUrl: string, tokenUrl: string, scopes: array<string>})
  | BasicAuth

type transformStep =
  | JSONPath({expression: string})
  | RegexExtract({pattern: string, group: int})
  | DateFormat({inputFormat: string, outputFormat: string})
  | Aggregate({operation: string, field: string})
  | Filter({condition: string})

type dataSourceConfig = {
  id: string,
  name: string,
  description: string,
  baseUrl: string,
  method: httpMethod,
  auth: authType,
  headers: Js.Dict.t<string>,
  queryParams: Js.Dict.t<string>,
  requestBody: option<string>,
  transformPipeline: array<transformStep>,
  cacheConfig: {
    enabled: bool,
    ttl: int,
  },
  rateLimiting: {
    enabled: bool,
    requestsPerMinute: int,
  },
}

type validationResult =
  | Valid
  | Invalid(array<string>)

let validateConfig = (config: dataSourceConfig): validationResult => {
  let errors = []

  if config.name == "" {
    errors->Js.Array2.push("Name is required")->ignore
  }

  if config.baseUrl == "" {
    errors->Js.Array2.push("Base URL is required")->ignore
  }

  // Validate URL format
  let urlPattern = %re("/^https?:\/\/.+/")
  if !Js.Re.test_(urlPattern, config.baseUrl) {
    errors->Js.Array2.push("Base URL must start with http:// or https://")->ignore
  }

  // Validate rate limiting
  if config.rateLimiting.enabled && config.rateLimiting.requestsPerMinute <= 0 {
    errors->Js.Array2.push("Requests per minute must be positive")->ignore
  }

  if errors->Js.Array2.length > 0 {
    Invalid(errors)
  } else {
    Valid
  }
}

let applyTransform = (data: Js.Json.t, step: transformStep): Js.Json.t => {
  switch step {
  | JSONPath({expression}) => {
      // Apply JSONPath expression
      // In production, use a JSONPath library
      data
    }
  | RegexExtract({pattern, group}) => {
      // Extract data using regex
      data
    }
  | DateFormat({inputFormat, outputFormat}) => {
      // Convert date formats
      data
    }
  | Aggregate({operation, field}) => {
      // Aggregate data (sum, avg, count, etc.)
      data
    }
  | Filter({condition}) => {
      // Filter data based on condition
      data
    }
  }
}

let buildDataSource = (config: dataSourceConfig): result<string, string> => {
  switch validateConfig(config) {
  | Invalid(errors) => Error("Validation failed: " ++ errors->Js.Array2.joinWith(", "))
  | Valid => {
      // Generate Julia code for the custom data source
      let juliaCode = `
# SPDX-License-Identifier: MPL-2.0
# Generated Data Source: ${config.name}

module ${config.id}DataSource

using HTTP, JSON3, Dates

struct ${config.id}Client
    base_url::String
    headers::Dict{String, String}
    cache_enabled::Bool
    cache_ttl::Int
    rate_limit::Int
end

function ${config.id}Client()
    ${config.id}Client(
        "${config.baseUrl}",
        Dict(${config.headers->Js.Dict.entries->Js.Array2.map(((k, v)) => `"${k}" => "${v}"`)->Js.Array2.joinWith(", ")}),
        ${config.cacheConfig.enabled ? "true" : "false"},
        ${config.cacheConfig.ttl->Belt.Int.toString},
        ${config.rateLimiting.enabled ? config.rateLimiting.requestsPerMinute->Belt.Int.toString : "60"}
    )
end

function fetch_data(client::${config.id}Client, params::Dict=Dict())
    url = client.base_url
    headers = copy(client.headers)

    # Apply authentication
    ${switch config.auth {
      | NoAuth => "# No authentication"
      | APIKey({headerName, prefix}) => {
          let prefixStr = switch prefix {
          | Some(p) => `"${p} "`
          | None => "\"\""
          }
          `headers["${headerName}"] = ${prefixStr} * get(ENV, "API_KEY", "")`
        }
      | Bearer({tokenUrl}) => `headers["Authorization"] = "Bearer " * get(ENV, "ACCESS_TOKEN", "")`
      | OAuth2(_) => "# OAuth2 authentication (implement token refresh)"
      | BasicAuth => `headers["Authorization"] = "Basic " * base64encode(get(ENV, "USERNAME", "") * ":" * get(ENV, "PASSWORD", ""))`
    }}

    # Make request
    response = HTTP.${switch config.method {
      | GET => "get"
      | POST => "post"
      | PUT => "put"
      | DELETE => "delete"
    }}(url, headers; query=params)

    # Parse response
    data = JSON3.read(String(response.body))

    # Apply transforms
    ${config.transformPipeline->Js.Array2.length > 0 ? "# Transform pipeline would be applied here" : ""}

    return data
end

export ${config.id}Client, fetch_data

end # module
`
      Ok(juliaCode)
    }
  }
}

let serializeConfig = (config: dataSourceConfig): string => {
  // Serialize to JSON for storage
  Js.Json.stringifyAny(config)->Belt.Option.getWithDefault("{}")
}

let deserializeConfig = (json: string): option<dataSourceConfig> => {
  // Deserialize from JSON
  None // Implement proper deserialization
}
