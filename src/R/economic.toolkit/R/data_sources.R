# SPDX-License-Identifier: PMPL-1.0-or-later
# SPDX-FileCopyrightText: 2024-2026 Hyperpolymath Contributors

#' FRED Data Source Client
#'
#' Federal Reserve Economic Data (FRED) client.
#'
#' @param client Optional EconomicToolkit client. If NULL, creates default REST client.
#' @return FRED client object
#' @export
#'
#' @examples
#' \dontrun{
#' fred <- FRED()
#' data <- fred$fetch("UNRATE", start_date = "2020-01-01", end_date = "2023-12-31")
#' results <- fred$search("unemployment")
#' }
FRED <- function(client = NULL) {
  if (is.null(client)) {
    client <- EconomicToolkit()
  }

  self <- list(
    source_id = "fred",
    source_name = "Federal Reserve Economic Data",
    client = client
  )

  self$fetch <- function(series_id, start_date = NULL, end_date = NULL) {
    self$client$fetch_series(self$source_id, series_id, start_date, end_date)
  }

  self$search <- function(query) {
    self$client$search_series(self$source_id, query)
  }

  class(self) <- c("FRED", "DataSource")
  return(self)
}

#' World Bank Data Source Client
#'
#' @param client Optional EconomicToolkit client
#' @return WorldBank client object
#' @export
WorldBank <- function(client = NULL) {
  if (is.null(client)) client <- EconomicToolkit()

  self <- list(
    source_id = "worldbank",
    source_name = "World Bank",
    client = client,
    fetch = function(series_id, start_date = NULL, end_date = NULL) {
      self$client$fetch_series(self$source_id, series_id, start_date, end_date)
    },
    search = function(query) {
      self$client$search_series(self$source_id, query)
    }
  )

  class(self) <- c("WorldBank", "DataSource")
  return(self)
}

#' IMF Data Source Client
#' @param client Optional EconomicToolkit client
#' @return IMF client object
#' @export
IMF <- function(client = NULL) {
  if (is.null(client)) client <- EconomicToolkit()
  self <- list(
    source_id = "imf",
    source_name = "International Monetary Fund",
    client = client,
    fetch = function(series_id, start_date = NULL, end_date = NULL) {
      self$client$fetch_series(self$source_id, series_id, start_date, end_date)
    },
    search = function(query) {
      self$client$search_series(self$source_id, query)
    }
  )
  class(self) <- c("IMF", "DataSource")
  return(self)
}

#' OECD Data Source Client
#' @param client Optional EconomicToolkit client
#' @return OECD client object
#' @export
OECD <- function(client = NULL) {
  if (is.null(client)) client <- EconomicToolkit()
  self <- list(
    source_id = "oecd",
    source_name = "OECD",
    client = client,
    fetch = function(series_id, start_date = NULL, end_date = NULL) {
      self$client$fetch_series(self$source_id, series_id, start_date, end_date)
    },
    search = function(query) {
      self$client$search_series(self$source_id, query)
    }
  )
  class(self) <- c("OECD", "DataSource")
  return(self)
}

#' @rdname FRED
#' @export
ECB <- function(client = NULL) {
  if (is.null(client)) client <- EconomicToolkit()
  self <- list(source_id = "ecb", source_name = "European Central Bank", client = client,
               fetch = function(series_id, start_date = NULL, end_date = NULL) {
                 self$client$fetch_series(self$source_id, series_id, start_date, end_date)
               },
               search = function(query) self$client$search_series(self$source_id, query))
  class(self) <- c("ECB", "DataSource")
  return(self)
}

#' @rdname FRED
#' @export
BEA <- function(client = NULL) {
  if (is.null(client)) client <- EconomicToolkit()
  self <- list(source_id = "bea", source_name = "Bureau of Economic Analysis", client = client,
               fetch = function(series_id, start_date = NULL, end_date = NULL) {
                 self$client$fetch_series(self$source_id, series_id, start_date, end_date)
               },
               search = function(query) self$client$search_series(self$source_id, query))
  class(self) <- c("BEA", "DataSource")
  return(self)
}

#' @rdname FRED
#' @export
Census <- function(client = NULL) {
  if (is.null(client)) client <- EconomicToolkit()
  self <- list(source_id = "census", source_name = "US Census Bureau", client = client,
               fetch = function(series_id, start_date = NULL, end_date = NULL) {
                 self$client$fetch_series(self$source_id, series_id, start_date, end_date)
               },
               search = function(query) self$client$search_series(self$source_id, query))
  class(self) <- c("Census", "DataSource")
  return(self)
}

#' @rdname FRED
#' @export
Eurostat <- function(client = NULL) {
  if (is.null(client)) client <- EconomicToolkit()
  self <- list(source_id = "eurostat", source_name = "Eurostat", client = client,
               fetch = function(series_id, start_date = NULL, end_date = NULL) {
                 self$client$fetch_series(self$source_id, series_id, start_date, end_date)
               },
               search = function(query) self$client$search_series(self$source_id, query))
  class(self) <- c("Eurostat", "DataSource")
  return(self)
}

#' @rdname FRED
#' @export
BIS <- function(client = NULL) {
  if (is.null(client)) client <- EconomicToolkit()
  self <- list(source_id = "bis", source_name = "Bank for International Settlements", client = client,
               fetch = function(series_id, start_date = NULL, end_date = NULL) {
                 self$client$fetch_series(self$source_id, series_id, start_date, end_date)
               },
               search = function(query) self$client$search_series(self$source_id, query))
  class(self) <- c("BIS", "DataSource")
  return(self)
}

#' @rdname FRED
#' @export
DBnomics <- function(client = NULL) {
  if (is.null(client)) client <- EconomicToolkit()
  self <- list(source_id = "dbnomics", source_name = "DBnomics", client = client,
               fetch = function(series_id, start_date = NULL, end_date = NULL) {
                 self$client$fetch_series(self$source_id, series_id, start_date, end_date)
               },
               search = function(query) self$client$search_series(self$source_id, query))
  class(self) <- c("DBnomics", "DataSource")
  return(self)
}
