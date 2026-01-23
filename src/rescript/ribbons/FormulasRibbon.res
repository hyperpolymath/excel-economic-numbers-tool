/**
 * Formulas Ribbon Tab
 *
 * Provides quick insertion of economic formulas:
 * - Elasticity calculations (price, income, cross-price)
 * - GDP growth (YoY, QoQ, MoM, CAGR)
 * - Inequality measures (Gini, Lorenz, Atkinson, Theil)
 * - Statistical functions
 */

type formulaCategory =
  | Elasticity
  | Growth
  | Inequality
  | Statistical
  | Financial

type formula = {
  name: string,
  category: formulaCategory,
  syntax: string,
  description: string,
  example: string,
}

// Formula definitions
let formulas: array<formula> = [
  // Elasticity
  {
    name: "ECON.ELASTICITY",
    category: Elasticity,
    syntax: "=ECON.ELASTICITY(quantities, prices, method)",
    description: "Calculate price elasticity of demand",
    example: "=ECON.ELASTICITY(A1:A10, B1:B10, \"midpoint\")",
  },
  {
    name: "ECON.INCOME_ELASTICITY",
    category: Elasticity,
    syntax: "=ECON.INCOME_ELASTICITY(quantities, incomes)",
    description: "Calculate income elasticity of demand",
    example: "=ECON.INCOME_ELASTICITY(A1:A10, B1:B10)",
  },
  {
    name: "ECON.CROSS_ELASTICITY",
    category: Elasticity,
    syntax: "=ECON.CROSS_ELASTICITY(quantity_x, price_y)",
    description: "Calculate cross-price elasticity",
    example: "=ECON.CROSS_ELASTICITY(A1:A10, B1:B10)",
  },
  // Growth
  {
    name: "ECON.GROWTH",
    category: Growth,
    syntax: "=ECON.GROWTH(values, method)",
    description: "Calculate growth rates (YoY, QoQ, MoM, CAGR)",
    example: "=ECON.GROWTH(A1:A10, \"YoY\")",
  },
  {
    name: "ECON.GDP_GROWTH",
    category: Growth,
    syntax: "=ECON.GDP_GROWTH(gdp_values, real, method)",
    description: "Calculate GDP growth rates",
    example: "=ECON.GDP_GROWTH(A1:A10, TRUE, \"YoY\")",
  },
  {
    name: "ECON.CAGR",
    category: Growth,
    syntax: "=ECON.CAGR(initial_value, final_value, periods)",
    description: "Compound Annual Growth Rate",
    example: "=ECON.CAGR(100, 150, 5)",
  },
  // Inequality
  {
    name: "ECON.GINI",
    category: Inequality,
    syntax: "=ECON.GINI(distribution)",
    description: "Calculate Gini coefficient",
    example: "=ECON.GINI(A1:A100)",
  },
  {
    name: "ECON.LORENZ",
    category: Inequality,
    syntax: "=ECON.LORENZ(distribution)",
    description: "Calculate Lorenz curve coordinates",
    example: "=ECON.LORENZ(A1:A100)",
  },
  {
    name: "ECON.ATKINSON",
    category: Inequality,
    syntax: "=ECON.ATKINSON(distribution, epsilon)",
    description: "Calculate Atkinson inequality index",
    example: "=ECON.ATKINSON(A1:A100, 0.5)",
  },
  {
    name: "ECON.THEIL",
    category: Inequality,
    syntax: "=ECON.THEIL(distribution)",
    description: "Calculate Theil inequality index",
    example: "=ECON.THEIL(A1:A100)",
  },
  {
    name: "ECON.PALMA",
    category: Inequality,
    syntax: "=ECON.PALMA(distribution)",
    description: "Calculate Palma ratio (top 10% / bottom 40%)",
    example: "=ECON.PALMA(A1:A100)",
  },
  // Statistical
  {
    name: "ECON.PERCENTILE",
    category: Statistical,
    syntax: "=ECON.PERCENTILE(data, p)",
    description: "Calculate percentile",
    example: "=ECON.PERCENTILE(A1:A100, 90)",
  },
  {
    name: "ECON.MOVING_AVG",
    category: Statistical,
    syntax: "=ECON.MOVING_AVG(data, window)",
    description: "Calculate moving average",
    example: "=ECON.MOVING_AVG(A1:A100, 7)",
  },
  {
    name: "ECON.NORMALIZE",
    category: Statistical,
    syntax: "=ECON.NORMALIZE(data, method)",
    description: "Normalize data (z-score, min-max, etc.)",
    example: "=ECON.NORMALIZE(A1:A100, \"z-score\")",
  },
  // Financial
  {
    name: "ECON.INFLATION_ADJUST",
    category: Financial,
    syntax: "=ECON.INFLATION_ADJUST(nominal, cpi_base, cpi_target)",
    description: "Adjust for inflation using CPI",
    example: "=ECON.INFLATION_ADJUST(100, 250, 270)",
  },
  {
    name: "ECON.REAL_VALUE",
    category: Financial,
    syntax: "=ECON.REAL_VALUE(nominal, deflator)",
    description: "Convert nominal to real values",
    example: "=ECON.REAL_VALUE(A1:A10, B1:B10)",
  },
]

type state = {
  selectedCategory: option<formulaCategory>,
  selectedFormula: option<formula>,
  searchQuery: string,
}

type action =
  | SelectCategory(option<formulaCategory>)
  | SelectFormula(formula)
  | UpdateSearch(string)
  | ClearSelection

// Reducer
let reducer = (state: state, action: action): state => {
  switch action {
  | SelectCategory(category) => {...state, selectedCategory: category}
  | SelectFormula(formula) => {...state, selectedFormula: Some(formula)}
  | UpdateSearch(query) => {...state, searchQuery: query}
  | ClearSelection => {
      ...state,
      selectedCategory: None,
      selectedFormula: None,
      searchQuery: "",
    }
  }
}

// Initial state
let initialState: state = {
  selectedCategory: None,
  selectedFormula: None,
  searchQuery: "",
}

// Helper functions
let categoryToString = (category: formulaCategory): string => {
  switch category {
  | Elasticity => "Elasticity"
  | Growth => "Growth"
  | Inequality => "Inequality"
  | Statistical => "Statistical"
  | Financial => "Financial"
  }
}

let filterFormulas = (formulas: array<formula>, category: option<formulaCategory>, query: string): array<formula> => {
  let byCategory = switch category {
  | Some(cat) => Belt.Array.keep(formulas, f => f.category === cat)
  | None => formulas
  }

  if query === "" {
    byCategory
  } else {
    let lowerQuery = Js.String.toLowerCase(query)
    Belt.Array.keep(byCategory, f =>
      Js.String.includes(lowerQuery, Js.String.toLowerCase(f.name)) ||
      Js.String.includes(lowerQuery, Js.String.toLowerCase(f.description))
    )
  }
}

// Components
module CategorySelector = {
  @react.component
  let make = (~selectedCategory: option<formulaCategory>, ~onSelect) => {
    let categories = [Elasticity, Growth, Inequality, Statistical, Financial]

    <div className="category-selector">
      <button
        onClick={_ => onSelect(None)}
        className={selectedCategory->Belt.Option.isNone ? "active" : ""}>
        {React.string("All")}
      </button>
      {Belt.Array.map(categories, cat =>
        <button
          key={categoryToString(cat)}
          onClick={_ => onSelect(Some(cat))}
          className={selectedCategory === Some(cat) ? "active" : ""}>
          {React.string(categoryToString(cat))}
        </button>
      )->React.array}
    </div>
  }
}

module FormulaList = {
  @react.component
  let make = (~formulas: array<formula>, ~onSelect) => {
    <div className="formula-list">
      {Belt.Array.length(formulas) === 0
        ? <p className="empty-state"> {React.string("No formulas found")} </p>
        : <div className="formula-grid">
            {Belt.Array.map(formulas, f =>
              <button key={f.name} onClick={_ => onSelect(f)} className="formula-button">
                <div className="formula-name"> {React.string(f.name)} </div>
                <div className="formula-description"> {React.string(f.description)} </div>
              </button>
            )->React.array}
          </div>}
    </div>
  }
}

module FormulaDetail = {
  @react.component
  let make = (~formula: option<formula>, ~onInsert, ~onClose) => {
    switch formula {
    | None => React.null
    | Some(f) =>
      <div className="formula-detail">
        <div className="detail-header">
          <h3> {React.string(f.name)} </h3>
          <button onClick={_ => onClose()} className="close-button">
            {React.string("×")}
          </button>
        </div>
        <div className="detail-content">
          <div className="detail-section">
            <strong> {React.string("Description:")} </strong>
            <p> {React.string(f.description)} </p>
          </div>
          <div className="detail-section">
            <strong> {React.string("Syntax:")} </strong>
            <code> {React.string(f.syntax)} </code>
          </div>
          <div className="detail-section">
            <strong> {React.string("Example:")} </strong>
            <code> {React.string(f.example)} </code>
          </div>
        </div>
        <div className="detail-actions">
          <button onClick={_ => onInsert(f)} className="btn-primary">
            {React.string("Insert Formula")}
          </button>
        </div>
      </div>
    }
  }
}

module SearchBar = {
  @react.component
  let make = (~query: string, ~onChange) => {
    <div className="search-bar">
      <input
        type_="text"
        value={query}
        onChange={e => onChange(ReactEvent.Form.target(e)["value"])}
        placeholder="Search formulas..."
        className="search-input"
      />
      {query !== ""
        ? <button onClick={_ => onChange("")} className="clear-button">
            {React.string("×")}
          </button>
        : React.null}
    </div>
  }
}

// Main component
@react.component
let make = () => {
  let (state, dispatch) = React.useReducer(reducer, initialState)

  let filteredFormulas = filterFormulas(formulas, state.selectedCategory, state.searchQuery)

  let handleInsert = (formula: formula) => {
    // Insert formula into active cell
    // This would use the spreadsheet adapter
    Js.Console.log("Inserting formula: " ++ formula.syntax)
  }

  <div className="formulas-ribbon">
    <div className="ribbon-section full-width">
      <div className="section-title"> {React.string("Search")} </div>
      <SearchBar query={state.searchQuery} onChange={query => dispatch(UpdateSearch(query))} />
    </div>

    <div className="ribbon-section full-width">
      <div className="section-title"> {React.string("Categories")} </div>
      <CategorySelector
        selectedCategory={state.selectedCategory}
        onSelect={cat => dispatch(SelectCategory(cat))}
      />
    </div>

    <div className="ribbon-section full-width">
      <div className="section-title">
        {React.string("Formulas (" ++ Belt.Int.toString(Belt.Array.length(filteredFormulas)) ++ ")")}
      </div>
      <FormulaList formulas={filteredFormulas} onSelect={f => dispatch(SelectFormula(f))} />
    </div>

    {state.selectedFormula->Belt.Option.isSome
      ? <div className="ribbon-section full-width">
          <FormulaDetail
            formula={state.selectedFormula}
            onInsert={handleInsert}
            onClose={() => dispatch(ClearSelection)}
          />
        </div>
      : React.null}
  </div>
}
