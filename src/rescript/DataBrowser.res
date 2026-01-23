// DataBrowser.res - Data source browser task pane component

type dataSource = {
  id: string,
  name: string,
  description: string,
  status: string,
}

type state = {
  sources: array<dataSource>,
  selectedSource: option<string>,
  searchQuery: string,
  results: array<string>,
  loading: bool,
}

type action =
  | LoadSources(array<dataSource>)
  | SelectSource(string)
  | UpdateSearch(string)
  | LoadResults(array<string>)
  | SetLoading(bool)

let initialState = {
  sources: [],
  selectedSource: None,
  searchQuery: "",
  results: [],
  loading: false,
}

let reducer = (state, action) => {
  switch action {
  | LoadSources(sources) => {...state, sources: sources}
  | SelectSource(sourceId) => {...state, selectedSource: Some(sourceId)}
  | UpdateSearch(query) => {...state, searchQuery: query}
  | LoadResults(results) => {...state, results: results, loading: false}
  | SetLoading(loading) => {...state, loading: loading}
  }
}

@react.component
let make = () => {
  let (state, dispatch) = React.useReducer(reducer, initialState)

  // Fetch data sources on mount
  React.useEffect0(() => {
    let fetchSources = async () => {
      try {
        let response = await Fetch.fetch("http://localhost:8080/api/v1/sources")
        let json = await Fetch.Response.json(response)
        // Parse and dispatch
        dispatch(LoadSources(json))
      } catch {
      | error => Js.Console.error(error)
      }
    }
    ignore(fetchSources())
    None
  })

  let handleSearch = async () => {
    switch state.selectedSource {
    | Some(sourceId) => {
        dispatch(SetLoading(true))
        try {
          let url = `http://localhost:8080/api/v1/sources/${sourceId}/search?q=${state.searchQuery}`
          let response = await Fetch.fetch(url)
          let json = await Fetch.Response.json(response)
          dispatch(LoadResults(json))
        } catch {
        | error => {
            Js.Console.error(error)
            dispatch(SetLoading(false))
          }
        }
      }
    | None => ()
    }
  }

  <div className="data-browser">
    <h2> {React.string("Data Sources")} </h2>
    <div className="source-selector">
      <select
        value={Belt.Option.getWithDefault(state.selectedSource, "")}
        onChange={e => {
          let value = ReactEvent.Form.target(e)["value"]
          dispatch(SelectSource(value))
        }}>
        <option value=""> {React.string("Select a data source...")} </option>
        {state.sources
        ->Belt.Array.map(source =>
          <option key={source.id} value={source.id}> {React.string(source.name)} </option>
        )
        ->React.array}
      </select>
    </div>
    <div className="search-box">
      <input
        type_="text"
        value={state.searchQuery}
        placeholder="Search for series..."
        onChange={e => {
          let value = ReactEvent.Form.target(e)["value"]
          dispatch(UpdateSearch(value))
        }}
      />
      <button onClick={_ => ignore(handleSearch())}> {React.string("Search")} </button>
    </div>
    {state.loading
      ? <div className="loading"> {React.string("Loading...")} </div>
      : <div className="results">
          {state.results
          ->Belt.Array.map(result => <div key={result} className="result-item"> {React.string(result)} </div>)
          ->React.array}
        </div>}
  </div>
}
