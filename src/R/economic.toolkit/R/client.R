# SPDX-License-Identifier: PMPL-1.0-or-later
# SPDX-FileCopyrightText: 2024-2026 Hyperpolymath Contributors

#' Economic Toolkit Client
#'
#' Main client for interacting with Economic Toolkit.
#' Supports both REST API and direct Julia modes.
#'
#' @param mode Character string: 'rest' or 'julia'. Default: 'rest'
#' @param api_url Character string: URL for REST API. Default: 'http://localhost:8080'
#' @param api_key Optional character string: API key for authentication
#'
#' @return EconomicToolkit client object
#' @export
#'
#' @examples
#' \dontrun{
#' # Initialize REST client
#' client <- EconomicToolkit(mode = "rest")
#'
#' # With API key
#' client <- EconomicToolkit(api_key = "your-key-here")
#'
#' # Check health
#' client$health()
#'
#' # List data sources
#' sources <- client$list_sources()
#' }
EconomicToolkit <- function(mode = "rest",
                             api_url = "http://localhost:8080",
                             api_key = NULL) {
  # Remove trailing slash from API URL
  api_url <- gsub("/$", "", api_url)

  # Create client object
  self <- list(
    mode = mode,
    api_url = api_url,
    api_key = api_key
  )

  # Initialize Julia if in julia mode
  if (mode == "julia") {
    if (!requireNamespace("JuliaCall", quietly = TRUE)) {
      stop("JuliaCall package required for julia mode. Install with: install.packages('JuliaCall')")
    }
    julia <- JuliaCall::julia_setup()
    julia$command("import Pkg")
    julia$command('Pkg.activate(".")')
    julia$command("using EconomicToolkit")
    self$julia <- julia
  }

  # Define methods
  self$fetch_series <- function(source, series_id, start_date = NULL, end_date = NULL) {
    if (self$mode == "rest") {
      # Build URL
      url <- paste0(self$api_url, "/api/v1/sources/", source, "/series/", series_id)

      # Build query parameters
      params <- list()
      if (!is.null(start_date)) params$start <- as.character(start_date)
      if (!is.null(end_date)) params$end <- as.character(end_date)

      # Make request
      headers <- c()
      if (!is.null(self$api_key)) {
        headers <- c(headers, Authorization = paste("Bearer", self$api_key))
      }

      response <- httr::GET(url, query = params, httr::add_headers(.headers = headers))
      httr::stop_for_status(response)
      return(jsonlite::fromJSON(httr::content(response, as = "text", encoding = "UTF-8")))

    } else if (self$mode == "julia") {
      # Call Julia directly
      client_class <- paste0(toupper(source), "Client")
      client <- self$julia$eval(paste0("EconomicToolkit.", client_class, "()"))

      jl_start <- if (!is.null(start_date)) {
        self$julia$eval(paste0("Date(\"", start_date, "\")"))
      } else {
        self$julia$eval("Date(1900, 1, 1)")
      }

      jl_end <- if (!is.null(end_date)) {
        self$julia$eval(paste0("Date(\"", end_date, "\")"))
      } else {
        self$julia$eval("today()")
      }

      result <- self$julia$call("EconomicToolkit.fetch_series", client, series_id, jl_start, jl_end)
      return(result)
    }
  }

  self$search_series <- function(source, query) {
    if (self$mode == "rest") {
      url <- paste0(self$api_url, "/api/v1/sources/", source, "/search")

      headers <- c()
      if (!is.null(self$api_key)) {
        headers <- c(headers, Authorization = paste("Bearer", self$api_key))
      }

      response <- httr::GET(url, query = list(q = query), httr::add_headers(.headers = headers))
      httr::stop_for_status(response)
      return(jsonlite::fromJSON(httr::content(response, as = "text", encoding = "UTF-8")))

    } else if (self$mode == "julia") {
      client_class <- paste0(toupper(source), "Client")
      client <- self$julia$eval(paste0("EconomicToolkit.", client_class, "()"))
      result <- self$julia$call("EconomicToolkit.search_series", client, query)
      return(result)
    }
  }

  self$list_sources <- function() {
    if (self$mode == "rest") {
      url <- paste0(self$api_url, "/api/v1/sources")

      headers <- c()
      if (!is.null(self$api_key)) {
        headers <- c(headers, Authorization = paste("Bearer", self$api_key))
      }

      response <- httr::GET(url, httr::add_headers(.headers = headers))
      httr::stop_for_status(response)
      return(jsonlite::fromJSON(httr::content(response, as = "text", encoding = "UTF-8")))

    } else if (self$mode == "julia") {
      return(list(
        list(id = "fred", name = "Federal Reserve Economic Data", status = "active"),
        list(id = "worldbank", name = "World Bank", status = "active"),
        list(id = "imf", name = "International Monetary Fund", status = "active"),
        list(id = "oecd", name = "OECD", status = "active"),
        list(id = "dbnomics", name = "DBnomics", status = "active"),
        list(id = "ecb", name = "European Central Bank", status = "active"),
        list(id = "bea", name = "Bureau of Economic Analysis", status = "stub"),
        list(id = "census", name = "Census Bureau", status = "stub"),
        list(id = "eurostat", name = "Eurostat", status = "stub"),
        list(id = "bis", name = "Bank for International Settlements", status = "stub")
      ))
    }
  }

  self$health <- function() {
    if (self$mode == "rest") {
      url <- paste0(self$api_url, "/health")

      headers <- c()
      if (!is.null(self$api_key)) {
        headers <- c(headers, Authorization = paste("Bearer", self$api_key))
      }

      response <- httr::GET(url, httr::add_headers(.headers = headers))
      httr::stop_for_status(response)
      return(jsonlite::fromJSON(httr::content(response, as = "text", encoding = "UTF-8")))

    } else if (self$mode == "julia") {
      return(list(status = "ok", version = "2.1.0", mode = "julia"))
    }
  }

  # Return client object
  class(self) <- "EconomicToolkit"
  return(self)
}
