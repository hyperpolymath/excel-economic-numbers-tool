/**
 * Constraint Editor Task Pane
 *
 * Provides a visual interface for defining and managing economic constraints
 * in the constraint propagation system. Allows users to:
 * - Define accounting identities (e.g., C + I + G + NX = GDP)
 * - Set variable bounds and fixed values
 * - Solve constraint systems
 * - Visualize constraint relationships
 */

// Constraint types
type constraintType =
  | Identity // Accounting identity (must hold exactly)
  | Inequality // Bounds constraint (<=, >=, <, >)
  | Fixed // Variable is fixed to a value

type operator =
  | Equal
  | LessThan
  | LessThanOrEqual
  | GreaterThan
  | GreaterThanOrEqual

type variable = {
  name: string,
  cellAddress: string,
  value: option<float>,
  isFixed: bool,
  lowerBound: option<float>,
  upperBound: option<float>,
}

type constraint = {
  id: string,
  name: string,
  constraintType: constraintType,
  equation: string, // e.g., "C + I + G + NX = GDP"
  operator: operator,
  rightHandSide: float,
  variables: array<string>, // Variable names referenced
  isActive: bool,
}

type state = {
  constraints: array<constraint>,
  variables: Map.t<string, variable>,
  selectedConstraint: option<string>,
  isSolving: bool,
  lastSolution: option<string>,
  errorMessage: option<string>,
}

type action =
  | AddConstraint(constraint)
  | UpdateConstraint(string, constraint)
  | DeleteConstraint(string)
  | ToggleConstraint(string)
  | SelectConstraint(option<string>)
  | AddVariable(variable)
  | UpdateVariable(string, variable)
  | SetFixedValue(string, float)
  | SolveConstraints
  | SolutionComplete(string)
  | SolutionFailed(string)
  | ClearError

// Reducer
let reducer = (state: state, action: action): state => {
  switch action {
  | AddConstraint(c) => {
      ...state,
      constraints: Belt.Array.concat(state.constraints, [c]),
    }
  | UpdateConstraint(id, c) => {
      ...state,
      constraints: Belt.Array.map(state.constraints, existing =>
        existing.id === id ? c : existing
      ),
    }
  | DeleteConstraint(id) => {
      ...state,
      constraints: Belt.Array.keep(state.constraints, c => c.id !== id),
      selectedConstraint: state.selectedConstraint === Some(id)
        ? None
        : state.selectedConstraint,
    }
  | ToggleConstraint(id) => {
      ...state,
      constraints: Belt.Array.map(state.constraints, c =>
        c.id === id ? {...c, isActive: !c.isActive} : c
      ),
    }
  | SelectConstraint(id) => {...state, selectedConstraint: id}
  | AddVariable(v) => {
      ...state,
      variables: Map.set(state.variables, v.name, v),
    }
  | UpdateVariable(name, v) => {
      ...state,
      variables: Map.set(state.variables, name, v),
    }
  | SetFixedValue(name, value) =>
    switch Map.get(state.variables, name) {
    | Some(v) => {
        ...state,
        variables: Map.set(
          state.variables,
          name,
          {...v, value: Some(value), isFixed: true},
        ),
      }
    | None => state
    }
  | SolveConstraints => {...state, isSolving: true, errorMessage: None}
  | SolutionComplete(msg) => {
      ...state,
      isSolving: false,
      lastSolution: Some(msg),
    }
  | SolutionFailed(error) => {
      ...state,
      isSolving: false,
      errorMessage: Some(error),
    }
  | ClearError => {...state, errorMessage: None}
  }
}

// Initial state
let initialState: state = {
  constraints: [],
  variables: Map.make(),
  selectedConstraint: None,
  isSolving: false,
  lastSolution: None,
  errorMessage: None,
}

// API calls to Julia backend
let solveConstraintSystem = async (constraints: array<constraint>, variables: Map.t<string, variable>) => {
  let url = "http://localhost:8080/api/v1/constraints/solve"

  let payload = {
    "constraints": Belt.Array.map(constraints, c => {
      "id": c.id,
      "equation": c.equation,
      "active": c.isActive,
    }),
    "variables": Belt.Map.toArray(variables)->Belt.Array.map(((name, v)) => {
      "name": name,
      "cellAddress": v.cellAddress,
      "value": v.value,
      "isFixed": v.isFixed,
      "lowerBound": v.lowerBound,
      "upperBound": v.upperBound,
    }),
  }

  let response = await Fetch.fetch(
    url,
    {
      method: #POST,
      headers: {"Content-Type": "application/json"},
      body: Js.Json.stringifyAny(payload)->Belt.Option.getExn,
    },
  )

  if response.ok {
    let json = await Fetch.Response.json(response)
    Ok(json)
  } else {
    Error("Failed to solve constraint system: " ++ response.statusText)
  }
}

// Components
module ConstraintList = {
  @react.component
  let make = (~constraints: array<constraint>, ~selectedId: option<string>, ~onSelect, ~onToggle, ~onDelete) => {
    <div className="constraint-list">
      <h3> {React.string("Constraints")} </h3>
      {Belt.Array.length(constraints) === 0
        ? <p className="empty-state"> {React.string("No constraints defined. Click 'Add Constraint' to get started.")} </p>
        : <ul>
            {Belt.Array.map(constraints, c =>
              <li
                key={c.id}
                className={selectedId === Some(c.id) ? "selected" : ""}
                onClick={_ => onSelect(Some(c.id))}>
                <div className="constraint-item">
                  <input
                    type_="checkbox"
                    checked={c.isActive}
                    onChange={_ => onToggle(c.id)}
                  />
                  <span className="constraint-name"> {React.string(c.name)} </span>
                  <code className="constraint-equation"> {React.string(c.equation)} </code>
                  <button onClick={_ => onDelete(c.id)} className="delete-btn">
                    {React.string("×")}
                  </button>
                </div>
              </li>
            )->React.array}
          </ul>}
    </div>
  }
}

module ConstraintForm = {
  @react.component
  let make = (~constraint: option<constraint>, ~onSave, ~onCancel) => {
    let (name, setName) = React.useState(() => constraint->Belt.Option.mapWithDefault("", c => c.name))
    let (equation, setEquation) = React.useState(() => constraint->Belt.Option.mapWithDefault("", c => c.equation))

    let handleSubmit = e => {
      ReactEvent.Form.preventDefault(e)
      let newConstraint: constraint = {
        id: constraint->Belt.Option.mapWithDefault(
          "c_" ++ Js.Date.now()->Belt.Float.toString,
          c => c.id,
        ),
        name: name,
        constraintType: Identity,
        equation: equation,
        operator: Equal,
        rightHandSide: 0.0,
        variables: [],
        isActive: true,
      }
      onSave(newConstraint)
    }

    <form onSubmit={handleSubmit} className="constraint-form">
      <div className="form-group">
        <label> {React.string("Constraint Name")} </label>
        <input
          type_="text"
          value={name}
          onChange={e => setName(ReactEvent.Form.target(e)["value"])}
          placeholder="e.g., GDP Identity"
          required={true}
        />
      </div>
      <div className="form-group">
        <label> {React.string("Equation")} </label>
        <input
          type_="text"
          value={equation}
          onChange={e => setEquation(ReactEvent.Form.target(e)["value"])}
          placeholder="e.g., C + I + G + NX = GDP"
          required={true}
        />
      </div>
      <div className="form-actions">
        <button type_="submit" className="btn-primary">
          {React.string("Save")}
        </button>
        <button type_="button" onClick={_ => onCancel()} className="btn-secondary">
          {React.string("Cancel")}
        </button>
      </div>
    </form>
  }
}

module SolverPanel = {
  @react.component
  let make = (~isSolving: bool, ~lastSolution: option<string>, ~errorMessage: option<string>, ~onSolve, ~onClearError) => {
    <div className="solver-panel">
      <h3> {React.string("Solver")} </h3>
      <button
        onClick={_ => onSolve()}
        disabled={isSolving}
        className="btn-primary btn-large">
        {React.string(isSolving ? "Solving..." : "Solve Constraints")}
      </button>

      {switch errorMessage {
      | Some(msg) =>
        <div className="error-message">
          <span> {React.string("Error: " ++ msg)} </span>
          <button onClick={_ => onClearError()} className="close-btn">
            {React.string("×")}
          </button>
        </div>
      | None => React.null
      }}

      {switch lastSolution {
      | Some(msg) =>
        <div className="success-message">
          <span> {React.string("✓ " ++ msg)} </span>
        </div>
      | None => React.null
      }}
    </div>
  }
}

// Main component
@react.component
let make = () => {
  let (state, dispatch) = React.useReducer(reducer, initialState)
  let (showForm, setShowForm) = React.useState(() => false)

  let handleSolve = async () => {
    dispatch(SolveConstraints)

    let result = await solveConstraintSystem(state.constraints, state.variables)

    switch result {
    | Ok(_json) => dispatch(SolutionComplete("Constraints solved successfully"))
    | Error(msg) => dispatch(SolutionFailed(msg))
    }
  }

  <div className="constraint-editor">
    <div className="header">
      <h2> {React.string("Constraint Editor")} </h2>
      <button onClick={_ => setShowForm(_ => true)} className="btn-primary">
        {React.string("+ Add Constraint")}
      </button>
    </div>

    {showForm
      ? <ConstraintForm
          constraint={None}
          onSave={c => {
            dispatch(AddConstraint(c))
            setShowForm(_ => false)
          }}
          onCancel={() => setShowForm(_ => false)}
        />
      : React.null}

    <ConstraintList
      constraints={state.constraints}
      selectedId={state.selectedConstraint}
      onSelect={id => dispatch(SelectConstraint(id))}
      onToggle={id => dispatch(ToggleConstraint(id))}
      onDelete={id => dispatch(DeleteConstraint(id))}
    />

    <SolverPanel
      isSolving={state.isSolving}
      lastSolution={state.lastSolution}
      errorMessage={state.errorMessage}
      onSolve={handleSolve}
      onClearError={() => dispatch(ClearError)}
    />

    <div className="help-text">
      <h4> {React.string("Usage Tips")} </h4>
      <ul>
        <li> {React.string("Define accounting identities like C + I + G + NX = GDP")} </li>
        <li> {React.string("Use spreadsheet cell references (e.g., A1, B2)")} </li>
        <li> {React.string("Check/uncheck constraints to enable/disable them")} </li>
        <li> {React.string("Click 'Solve' to propagate constraints throughout the spreadsheet")} </li>
      </ul>
    </div>
  </div>
}
