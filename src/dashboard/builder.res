// SPDX-License-Identifier: PMPL-1.0-or-later
/**
 * Visual Dashboard Builder - v3.0
 *
 * Drag-and-drop dashboard builder with real-time data binding
 */

type chartType =
  | LineChart
  | BarChart
  | PieChart
  | ScatterPlot
  | Heatmap
  | GeoMap
  | Candlestick
  | Waterfall

type widget = {
  id: string,
  widgetType: chartType,
  title: string,
  dataSource: string,
  dataQuery: string,
  position: {
    x: int,
    y: int,
    width: int,
    height: int,
  },
  config: {
    xAxis: option<string>,
    yAxis: option<string>,
    colors: array<string>,
    showLegend: bool,
    showGrid: bool,
    interactive: bool,
  },
  refreshInterval: option<int>, // milliseconds
}

type dashboard = {
  id: string,
  name: string,
  description: string,
  layout: array<widget>,
  theme: string,
  filters: array<{
    id: string,
    label: string,
    filterType: string,
    defaultValue: string,
  }>,
  metadata: {
    createdBy: string,
    createdAt: string,
    updatedAt: string,
    isPublic: bool,
    tags: array<string>,
  },
}

type layoutTemplate =
  | SinglePanel
  | TwoColumn
  | ThreeColumn
  | Grid2x2
  | Grid3x3
  | Custom

let createWidget = (
  ~widgetType: chartType,
  ~title: string,
  ~dataSource: string,
  ~dataQuery: string,
  ~position: (int, int, int, int),
  (),
): widget => {
  let (x, y, width, height) = position
  {
    id: Js.Date.now()->Belt.Float.toString,
    widgetType: widgetType,
    title: title,
    dataSource: dataSource,
    dataQuery: dataQuery,
    position: {
      x: x,
      y: y,
      width: width,
      height: height,
    },
    config: {
      xAxis: None,
      yAxis: None,
      colors: ["#3b82f6", "#10b981", "#f59e0b", "#ef4444"],
      showLegend: true,
      showGrid: true,
      interactive: true,
    },
    refreshInterval: None,
  }
}

let applyTemplate = (template: layoutTemplate, widgets: array<widget>): array<widget> => {
  switch template {
  | SinglePanel =>
      widgets->Js.Array2.mapi((w, i) => {
        {...w, position: {x: 0, y: i * 400, width: 12, height: 400}}
      })
  | TwoColumn =>
      widgets->Js.Array2.mapi((w, i) => {
        let col = mod(i, 2)
        let row = i / 2
        {...w, position: {x: col * 6, y: row * 400, width: 6, height: 400}}
      })
  | ThreeColumn =>
      widgets->Js.Array2.mapi((w, i) => {
        let col = mod(i, 3)
        let row = i / 3
        {...w, position: {x: col * 4, y: row * 400, width: 4, height: 400}}
      })
  | Grid2x2 =>
      widgets->Js.Array2.slice(~start=0, ~end_=4)->Js.Array2.mapi((w, i) => {
        let col = mod(i, 2)
        let row = i / 2
        {...w, position: {x: col * 6, y: row * 6, width: 6, height: 6}}
      })
  | Grid3x3 =>
      widgets->Js.Array2.slice(~start=0, ~end_=9)->Js.Array2.mapi((w, i) => {
        let col = mod(i, 3)
        let row = i / 3
        {...w, position: {x: col * 4, y: row * 4, width: 4, height: 4}}
      })
  | Custom => widgets
  }
}

let validateDashboard = (dashboard: dashboard): result<unit, array<string>> => {
  let errors = []

  if dashboard.name == "" {
    errors->Js.Array2.push("Dashboard name is required")->ignore
  }

  if dashboard.layout->Js.Array2.length == 0 {
    errors->Js.Array2.push("Dashboard must have at least one widget")->ignore
  }

  // Check for overlapping widgets
  let hasOverlaps = dashboard.layout->Js.Array2.some(w1 => {
    dashboard.layout->Js.Array2.some(w2 => {
      if w1.id == w2.id {
        false
      } else {
        let x1 = w1.position.x
        let y1 = w1.position.y
        let w1Width = w1.position.width
        let h1 = w1.position.height

        let x2 = w2.position.x
        let y2 = w2.position.y
        let w2Width = w2.position.width
        let h2 = w2.position.height

        x1 < x2 + w2Width && x1 + w1Width > x2 && y1 < y2 + h2 && y1 + h1 > y2
      }
    })
  })

  if hasOverlaps {
    errors->Js.Array2.push("Widgets cannot overlap")->ignore
  }

  if errors->Js.Array2.length > 0 {
    Error(errors)
  } else {
    Ok()
  }
}

let exportDashboard = (dashboard: dashboard, format: string): string => {
  switch format {
  | "json" => Js.Json.stringifyAny(dashboard)->Belt.Option.getWithDefault("{}")
  | "html" => {
      // Export as standalone HTML
      `<!DOCTYPE html>
<html>
<head>
  <title>${dashboard.name}</title>
  <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
</head>
<body>
  <div id="dashboard">
    <h1>${dashboard.name}</h1>
    <div class="widgets">
      ${dashboard.layout->Js.Array2.map(w => `
        <div class="widget" style="grid-column: span ${w.position.width->Belt.Int.toString}; grid-row: span ${w.position.height->Belt.Int.toString};">
          <h3>${w.title}</h3>
          <canvas id="${w.id}"></canvas>
        </div>
      `)->Js.Array2.joinWith("\n")}
    </div>
  </div>
</body>
</html>`
    }
  | _ => ""
  }
}

let cloneDashboard = (dashboard: dashboard, newName: string): dashboard => {
  {
    ...dashboard,
    id: Js.Date.now()->Belt.Float.toString,
    name: newName,
    metadata: {
      ...dashboard.metadata,
      createdAt: Js.Date.toISOString(Js.Date.make()),
      updatedAt: Js.Date.toISOString(Js.Date.make()),
    },
  }
}
