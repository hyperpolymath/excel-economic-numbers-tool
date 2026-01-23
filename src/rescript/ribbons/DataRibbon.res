/**
 * Data Ribbon Tab
 *
 * Provides quick access to data source operations:
 * - Import data from sources (FRED, World Bank, etc.)
 * - Refresh data
 * - Search for series
 * - View cache status
 */

type dataSource =
  | FRED
  | WorldBank
  | IMF
  | OECD
  | DBnomics
  | ECB
  | BEA
  | Census
  | Eurostat
  | BIS

let dataSourceToString = (source: dataSource): string => {
  switch source {
  | FRED => "FRED"
  | WorldBank => "World Bank"
  | IMF => "IMF"
  | OECD => "OECD"
  | DBnomics => "DBnomics"
  | ECB => "ECB"
  | BEA => "BEA"
  | Census => "Census Bureau"
  | Eurostat => "Eurostat"
  | BIS => "BIS"
  }
}

type state = {
  selectedSource: option<dataSource>,
  isImporting: bool,
  lastImport: option<string>,
  cacheStatus: option<string>,
}

type action =
  | SelectSource(dataSource)
  | StartImport
  | ImportComplete(string)
  | ImportFailed(string)
  | UpdateCacheStatus(string)

// Reducer
let reducer = (state: state, action: action): state => {
  switch action {
  | SelectSource(source) => {...state, selectedSource: Some(source)}
  | StartImport => {...state, isImporting: true}
  | ImportComplete(msg) => {
      ...state,
      isImporting: false,
      lastImport: Some(msg),
    }
  | ImportFailed(msg) => {
      ...state,
      isImporting: false,
      lastImport: Some("Error: " ++ msg),
    }
  | UpdateCacheStatus(status) => {...state, cacheStatus: Some(status)}
  }
}

// Initial state
let initialState: state = {
  selectedSource: None,
  isImporting: false,
  lastImport: None,
  cacheStatus: None,
}

// API calls
let fetchCacheStatus = async () => {
  let url = "http://localhost:8080/api/v1/cache/stats"
  let response = await Fetch.fetch(url)

  if response.ok {
    let json = await Fetch.Response.json(response)
    Ok(json)
  } else {
    Error("Failed to fetch cache status")
  }
}

let importData = async (source: dataSource, seriesId: string, startDate: string, endDate: string) => {
  let sourceStr = dataSourceToString(source)->Js.String.toLowerCase
  let url = `http://localhost:8080/api/v1/sources/${sourceStr}/series`

  let params = {
    "seriesId": seriesId,
    "startDate": startDate,
    "endDate": endDate,
  }

  let queryString =
    Belt.Array.map(Js.Dict.entries(params), ((key, value)) => key ++ "=" ++ value)
    ->Js.Array2.joinWith("&")

  let response = await Fetch.fetch(url ++ "?" ++ queryString)

  if response.ok {
    let json = await Fetch.Response.json(response)
    Ok(json)
  } else {
    Error("Failed to import data from " ++ dataSourceToString(source))
  }
}

// Components
module SourceSelector = {
  @react.component
  let make = (~selectedSource: option<dataSource>, ~onSelect) => {
    let sources = [FRED, WorldBank, IMF, OECD, DBnomics, ECB, BEA, Census, Eurostat, BIS]

    <div className="source-selector">
      <label> {React.string("Data Source:")} </label>
      <select
        value={selectedSource->Belt.Option.map(dataSourceToString)->Belt.Option.getWithDefault("")}
        onChange={e => {
          let value = ReactEvent.Form.target(e)["value"]
          switch Belt.Array.getBy(sources, s => dataSourceToString(s) === value) {
          | Some(source) => onSelect(source)
          | None => ()
          }
        }}>
        <option value=""> {React.string("Select a source...")} </option>
        {Belt.Array.map(sources, source =>
          <option key={dataSourceToString(source)} value={dataSourceToString(source)}>
            {React.string(dataSourceToString(source))}
          </option>
        )->React.array}
      </select>
    </div>
  }
}

module QuickActions = {
  @react.component
  let make = (~source: option<dataSource>, ~isImporting: bool, ~onImport, ~onRefresh, ~onSearch, ~onBrowse) => {
    <div className="quick-actions">
      <button
        onClick={_ => onImport()}
        disabled={source->Belt.Option.isNone || isImporting}
        className="ribbon-button"
        title="Import data from selected source">
        <div className="icon"> {React.string("📥")} </div>
        <div className="label"> {React.string("Import Data")} </div>
      </button>

      <button
        onClick={_ => onRefresh()}
        disabled={isImporting}
        className="ribbon-button"
        title="Refresh all data in spreadsheet">
        <div className="icon"> {React.string("🔄")} </div>
        <div className="label"> {React.string("Refresh")} </div>
      </button>

      <button
        onClick={_ => onSearch()}
        disabled={source->Belt.Option.isNone}
        className="ribbon-button"
        title="Search for data series">
        <div className="icon"> {React.string("🔍")} </div>
        <div className="label"> {React.string("Search")} </div>
      </button>

      <button
        onClick={_ => onBrowse()}
        className="ribbon-button"
        title="Browse all data sources">
        <div className="icon"> {React.string("📊")} </div>
        <div className="label"> {React.string("Browse")} </div>
      </button>
    </div>
  }
}

module CachePanel = {
  @react.component
  let make = (~cacheStatus: option<string>, ~onClearCache, ~onRefreshStatus) => {
    <div className="cache-panel">
      <div className="panel-header">
        <span> {React.string("Cache Status")} </span>
        <button onClick={_ => onRefreshStatus()} className="icon-button" title="Refresh cache status">
          {React.string("🔄")}
        </button>
      </div>
      <div className="cache-info">
        {switch cacheStatus {
        | Some(status) => React.string(status)
        | None => React.string("Loading...")
        }}
      </div>
      <button onClick={_ => onClearCache()} className="btn-secondary">
        {React.string("Clear Cache")}
      </button>
    </div>
  }
}

// Main component
@react.component
let make = () => {
  let (state, dispatch) = React.useReducer(reducer, initialState)

  // Load cache status on mount
  React.useEffect0(() => {
    let _ = async () => {
      let result = await fetchCacheStatus()
      switch result {
      | Ok(json) =>
        dispatch(UpdateCacheStatus(Js.Json.stringifyAny(json)->Belt.Option.getWithDefault("OK")))
      | Error(msg) => dispatch(UpdateCacheStatus("Error: " ++ msg))
      }
    }
    None
  })

  let handleImport = () => {
    // This would open a dialog to get series ID and dates
    // For now, just a placeholder
    dispatch(StartImport)
    // In real implementation, would show import dialog
  }

  let handleRefresh = () => {
    // Refresh all data in the spreadsheet
    Js.Console.log("Refreshing all data...")
  }

  let handleSearch = () => {
    // Open search dialog
    Js.Console.log("Opening search dialog...")
  }

  let handleBrowse = () => {
    // Open data browser task pane
    Js.Console.log("Opening data browser...")
  }

  let handleClearCache = () => {
    Js.Console.log("Clearing cache...")
  }

  let handleRefreshStatus = async () => {
    let result = await fetchCacheStatus()
    switch result {
    | Ok(json) =>
      dispatch(UpdateCacheStatus(Js.Json.stringifyAny(json)->Belt.Option.getWithDefault("OK")))
    | Error(msg) => dispatch(UpdateCacheStatus("Error: " ++ msg))
    }
  }

  <div className="data-ribbon">
    <div className="ribbon-section">
      <div className="section-title"> {React.string("Source")} </div>
      <SourceSelector
        selectedSource={state.selectedSource}
        onSelect={source => dispatch(SelectSource(source))}
      />
    </div>

    <div className="ribbon-section">
      <div className="section-title"> {React.string("Actions")} </div>
      <QuickActions
        source={state.selectedSource}
        isImporting={state.isImporting}
        onImport={handleImport}
        onRefresh={handleRefresh}
        onSearch={handleSearch}
        onBrowse={handleBrowse}
      />
    </div>

    <div className="ribbon-section">
      <div className="section-title"> {React.string("Cache")} </div>
      <CachePanel
        cacheStatus={state.cacheStatus}
        onClearCache={handleClearCache}
        onRefreshStatus={handleRefreshStatus}
      />
    </div>
  </div>
}
