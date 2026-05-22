// SPDX-License-Identifier: MPL-2.0
// Economic Toolkit Web Application (ReScript)

module App = {
  open RescriptCore

  type state = {
    selectedSource: option<string>,
    seriesId: string,
    startDate: string,
    endDate: string,
    data: option<array<float>>,
    loading: bool,
    error: option<string>,
  }

  type action =
    | SelectSource(string)
    | UpdateSeriesId(string)
    | UpdateStartDate(string)
    | UpdateEndDate(string)
    | FetchData
    | FetchSuccess(array<float>)
    | FetchError(string)
    | ClearError

  let initialState = {
    selectedSource: None,
    seriesId: "",
    startDate: "",
    endDate: "",
    data: None,
    loading: false,
    error: None,
  }

  let reducer = (state, action) => {
    switch action {
    | SelectSource(source) => {...state, selectedSource: Some(source)}
    | UpdateSeriesId(id) => {...state, seriesId: id}
    | UpdateStartDate(date) => {...state, startDate: date}
    | UpdateEndDate(date) => {...state, endDate: date}
    | FetchData => {...state, loading: true, error: None}
    | FetchSuccess(data) => {...state, data: Some(data), loading: false}
    | FetchError(msg) => {...state, error: Some(msg), loading: false}
    | ClearError => {...state, error: None}
    }
  }

  @react.component
  let make = () => {
    let (state, dispatch) = React.useReducer(reducer, initialState)

    let fetchData = () => {
      dispatch(FetchData)

      // Fetch from API
      switch state.selectedSource {
      | Some(source) => {
          let apiUrl = "http://localhost:8080"
          let url = `${apiUrl}/api/v1/sources/${source}/series/${state.seriesId}?start=${state.startDate}&end=${state.endDate}`

          Fetch.fetch(url)
          ->Promise.then(response => response->Fetch.Response.json)
          ->Promise.then(json => {
            // Parse JSON and extract data
            // Simplified - real implementation would parse properly
            dispatch(FetchSuccess([]))
            Promise.resolve()
          })
          ->Promise.catch(error => {
            dispatch(FetchError("Failed to fetch data"))
            Promise.resolve()
          })
          ->ignore
        }
      | None => dispatch(FetchError("No source selected"))
      }
    }

    <div className="container mx-auto p-4">
      <h1 className="text-3xl font-bold mb-6"> {"Economic Toolkit"->React.string} </h1>

      <div className="mb-4">
        <label className="block text-sm font-medium mb-2">
          {"Data Source"->React.string}
        </label>
        <select
          className="w-full border rounded px-3 py-2"
          value={state.selectedSource->Option.getOr("")}
          onChange={e => {
            let value = e->ReactEvent.Form.target["value"]
            dispatch(SelectSource(value))
          }}>
          <option value=""> {"Select a source..."->React.string} </option>
          <option value="fred"> {"FRED"->React.string} </option>
          <option value="worldbank"> {"World Bank"->React.string} </option>
          <option value="imf"> {"IMF"->React.string} </option>
          <option value="oecd"> {"OECD"->React.string} </option>
        </select>
      </div>

      <div className="mb-4">
        <label className="block text-sm font-medium mb-2">
          {"Series ID"->React.string}
        </label>
        <input
          type_="text"
          className="w-full border rounded px-3 py-2"
          value={state.seriesId}
          onChange={e => {
            let value = e->ReactEvent.Form.target["value"]
            dispatch(UpdateSeriesId(value))
          }}
        />
      </div>

      <div className="grid grid-cols-2 gap-4 mb-4">
        <div>
          <label className="block text-sm font-medium mb-2">
            {"Start Date"->React.string}
          </label>
          <input
            type_="date"
            className="w-full border rounded px-3 py-2"
            value={state.startDate}
            onChange={e => {
              let value = e->ReactEvent.Form.target["value"]
              dispatch(UpdateStartDate(value))
            }}
          />
        </div>
        <div>
          <label className="block text-sm font-medium mb-2">
            {"End Date"->React.string}
          </label>
          <input
            type_="date"
            className="w-full border rounded px-3 py-2"
            value={state.endDate}
            onChange={e => {
              let value = e->ReactEvent.Form.target["value"]
              dispatch(UpdateEndDate(value))
            }}
          />
        </div>
      </div>

      <button
        className="bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600"
        onClick={_ => fetchData()}
        disabled={state.loading}>
        {(state.loading ? "Loading..." : "Fetch Data")->React.string}
      </button>

      {switch state.error {
      | Some(msg) => <div className="mt-4 p-4 bg-red-100 text-red-700 rounded">
          {msg->React.string}
        </div>
      | None => React.null
      }}

      {switch state.data {
      | Some(data) => <div className="mt-6">
          <h2 className="text-xl font-bold mb-4"> {"Results"->React.string} </h2>
          <div className="border rounded p-4">
            {`Found ${data->Array.length->Int.toString} data points`->React.string}
          </div>
        </div>
      | None => React.null
      }}
    </div>
  }
}
