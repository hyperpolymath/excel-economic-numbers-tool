// FormulaBuilder.res - Formula builder task pane component

type formula = {
  id: string,
  name: string,
  description: string,
  parameters: array<string>,
}

type state = {
  formulas: array<formula>,
  selectedFormula: option<formula>,
  parameterValues: Js.Dict.t<string>,
}

type action =
  | LoadFormulas(array<formula>)
  | SelectFormula(formula)
  | UpdateParameter(string, string)
  | ClearSelection

let initialState = {
  formulas: [],
  selectedFormula: None,
  parameterValues: Js.Dict.empty(),
}

let reducer = (state, action) => {
  switch action {
  | LoadFormulas(formulas) => {...state, formulas: formulas}
  | SelectFormula(formula) => {...state, selectedFormula: Some(formula)}
  | UpdateParameter(param, value) => {
      let newParams = Js.Dict.fromArray(Js.Dict.entries(state.parameterValues))
      Js.Dict.set(newParams, param, value)
      {...state, parameterValues: newParams}
    }
  | ClearSelection => {...state, selectedFormula: None, parameterValues: Js.Dict.empty()}
  }
}

@react.component
let make = () => {
  let (state, dispatch) = React.useReducer(reducer, initialState)

  // Load available formulas
  React.useEffect0(() => {
    let defaultFormulas = [
      {id: "elasticity", name: "Elasticity", description: "Calculate price elasticity", parameters: ["prices", "quantities"]},
      {id: "growth", name: "GDP Growth", description: "Calculate growth rates", parameters: ["values", "dates", "method"]},
      {id: "gini", name: "Gini Coefficient", description: "Calculate inequality", parameters: ["incomes"]},
    ]
    dispatch(LoadFormulas(defaultFormulas))
    None
  })

  let insertFormula = () => {
    switch state.selectedFormula {
    | Some(formula) => {
        // Build formula string
        let params = formula.parameters
          ->Belt.Array.map(p => Js.Dict.get(state.parameterValues, p)->Belt.Option.getWithDefault(""))
          ->Js.Array2.joinWith(", ")
        let formulaStr = `=ECON.${String.uppercase_ascii(formula.id)}(${params})`

        // Insert into Excel/LibreOffice
        Js.Console.log(formulaStr)
        // TODO: Call adapter to insert into active cell
      }
    | None => ()
    }
  }

  <div className="formula-builder">
    <h2> {React.string("Formula Builder")} </h2>
    <div className="formula-list">
      <h3> {React.string("Available Formulas")} </h3>
      {state.formulas
      ->Belt.Array.map(formula =>
        <div
          key={formula.id}
          className="formula-item"
          onClick={_ => dispatch(SelectFormula(formula))}>
          <strong> {React.string(formula.name)} </strong>
          <p> {React.string(formula.description)} </p>
        </div>
      )
      ->React.array}
    </div>
    {switch state.selectedFormula {
    | Some(formula) =>
      <div className="formula-editor">
        <h3> {React.string(formula.name)} </h3>
        <p> {React.string(formula.description)} </p>
        <div className="parameters">
          {formula.parameters
          ->Belt.Array.map(param =>
            <div key={param} className="parameter">
              <label> {React.string(param)} </label>
              <input
                type_="text"
                value={Js.Dict.get(state.parameterValues, param)->Belt.Option.getWithDefault("")}
                onChange={e => {
                  let value = ReactEvent.Form.target(e)["value"]
                  dispatch(UpdateParameter(param, value))
                }}
              />
            </div>
          )
          ->React.array}
        </div>
        <button onClick={_ => insertFormula()}> {React.string("Insert Formula")} </button>
      </div>
    | None => React.null
    }}
  </div>
}
