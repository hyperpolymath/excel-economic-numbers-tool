// SPDX-License-Identifier: PMPL-1.0-or-later
/**
 * Geographic Visualizations - v7.0
 *
 * Heatmaps, choropleth maps, and bubble maps for economic data
 */

type mapProjection =
  | Mercator
  | Robinson
  | Orthographic
  | Equirectangular

type geoDataPoint = {
  country: string,
  countryCode: string,
  value: float,
  lat: float,
  lon: float,
}

type choroplethConfig = {
  projection: mapProjection,
  colorScale: array<string>,
  valueRange: (float, float),
  showLegend: bool,
  showTooltips: bool,
  highlightOnHover: bool,
}

type heatmapPoint = {
  x: float,
  y: float,
  intensity: float,
}

type bubbleMapPoint = {
  lat: float,
  lon: float,
  value: float,
  label: string,
  color: string,
}

/**
 * Create choropleth map configuration
 */
let createChoroplethConfig = (
  ~projection: mapProjection=Mercator,
  ~colorScale: array<string>=["#fee5d9", "#fcae91", "#fb6a4a", "#de2d26", "#a50f15"],
  ~valueRange: (float, float)=(0.0, 100.0),
  ~showLegend: bool=true,
  ~showTooltips: bool=true,
  ~highlightOnHover: bool=true,
  (),
): choroplethConfig => {
  projection: projection,
  colorScale: colorScale,
  valueRange: valueRange,
  showLegend: showLegend,
  showTooltips: showTooltips,
  highlightOnHover: highlightOnHover,
}

/**
 * Map value to color using linear interpolation
 */
let valueToColor = (value: float, config: choroplethConfig): string => {
  let (minValue, maxValue) = config.valueRange
  let normalized = if maxValue > minValue {
    (value -. minValue) /. (maxValue -. minValue)
  } else {
    0.5
  }

  let normalized = normalized->Js.Math.max_float(0.0)->Js.Math.min_float(1.0)

  let numColors = config.colorScale->Js.Array2.length
  let index = Js.Math.floor_float(normalized *. Belt.Int.toFloat(numColors - 1))
  let index = index->Belt.Float.toInt->Js.Math.min_int(numColors - 1)->Js.Math.max_int(0)

  config.colorScale[index]->Belt.Option.getWithDefault("#cccccc")
}

/**
 * Convert lat/lon to screen coordinates (Mercator projection)
 */
let latLonToMercator = (lat: float, lon: float, width: int, height: int): (float, float) => {
  let x = (lon +. 180.0) /. 360.0 *. Belt.Int.toFloat(width)

  let latRad = lat *. Js.Math._PI /. 180.0
  let mercN = Js.Math.log(Js.Math.tan(Js.Math._PI /. 4.0 +. latRad /. 2.0))
  let y = Belt.Int.toFloat(height) /. 2.0 -. (Belt.Int.toFloat(width) *. mercN /. (2.0 *. Js.Math._PI))

  (x, y)
}

/**
 * Generate SVG for choropleth map
 */
let renderChoropleth = (
  data: array<geoDataPoint>,
  config: choroplethConfig,
  width: int,
  height: int,
): string => {
  let svg = `<svg width="${width->Belt.Int.toString}" height="${height->Belt.Int.toString}" xmlns="http://www.w3.org/2000/svg">`

  // In production, would render actual country shapes using TopoJSON/GeoJSON
  // This is a simplified representation
  let countriesRendered = data->Js.Array2.map(point => {
    let color = valueToColor(point.value, config)
    let (x, y) = latLonToMercator(point.lat, point.lon, width, height)

    `<circle cx="${x->Js.Float.toString}" cy="${y->Js.Float.toString}" r="10" fill="${color}" opacity="0.8">
      <title>${point.country}: ${point.value->Js.Float.toString}</title>
     </circle>`
  })->Js.Array2.joinWith("\n")

  svg ++ "\n" ++ countriesRendered ++ "\n" ++ "</svg>"
}

/**
 * Generate heatmap
 */
let renderHeatmap = (
  points: array<heatmapPoint>,
  width: int,
  height: int,
  ~radius: float=20.0,
  (),
): string => {
  let svg = `<svg width="${width->Belt.Int.toString}" height="${height->Belt.Int.toString}" xmlns="http://www.w3.org/2000/svg">`

  // Create radial gradients for each point
  let defs = "<defs>"
  let circles = points->Js.Array2.mapi((point, i) => {
    let gradientId = `gradient_${i->Belt.Int.toString}`
    let opacity = point.intensity->Js.Math.min_float(1.0)->Js.Math.max_float(0.0)

    let gradient = `
      <radialGradient id="${gradientId}">
        <stop offset="0%" stop-color="red" stop-opacity="${opacity->Js.Float.toString}" />
        <stop offset="100%" stop-color="red" stop-opacity="0" />
      </radialGradient>`

    let circle = `<circle cx="${point.x->Js.Float.toString}" cy="${point.y->Js.Float.toString}" r="${radius->Js.Float.toString}" fill="url(#${gradientId})" />`

    (gradient, circle)
  })

  let gradients = circles->Js.Array2.map(((g, _)) => g)->Js.Array2.joinWith("\n")
  let circleElements = circles->Js.Array2.map(((_, c)) => c)->Js.Array2.joinWith("\n")

  svg ++ "\n" ++ defs ++ "\n" ++ gradients ++ "\n</defs>\n" ++ circleElements ++ "\n</svg>"
}

/**
 * Generate bubble map
 */
let renderBubbleMap = (
  points: array<bubbleMapPoint>,
  width: int,
  height: int,
  ~maxBubbleSize: float=50.0,
  (),
): string => {
  let svg = `<svg width="${width->Belt.Int.toString}" height="${height->Belt.Int.toString}" xmlns="http://www.w3.org/2000/svg">`

  // Find max value for scaling
  let maxValue = points
    ->Js.Array2.map(p => p.value)
    ->Js.Array2.reduce((a, b) => Js.Math.max_float(a, b), 0.0)

  let bubbles = points->Js.Array2.map(point => {
    let (x, y) = latLonToMercator(point.lat, point.lon, width, height)
    let radius = if maxValue > 0.0 {
      Js.Math.sqrt(point.value /. maxValue) *. maxBubbleSize
    } else {
      5.0
    }

    `<circle cx="${x->Js.Float.toString}" cy="${y->Js.Float.toString}" r="${radius->Js.Float.toString}" fill="${point.color}" opacity="0.6" stroke="white" stroke-width="2">
      <title>${point.label}: ${point.value->Js.Float.toString}</title>
     </circle>`
  })->Js.Array2.joinWith("\n")

  svg ++ "\n" ++ bubbles ++ "\n</svg>"
}

/**
 * Generate legend for choropleth
 */
let generateLegend = (config: choroplethConfig, width: int): string => {
  if !config.showLegend {
    ""
  } else {
    let (minValue, maxValue) = config.valueRange
    let legendWidth = width / 5
    let legendHeight = 20

    let svg = `<svg width="${legendWidth->Belt.Int.toString}" height="${(legendHeight + 40)->Belt.Int.toString}" xmlns="http://www.w3.org/2000/svg">`

    let colorStops = config.colorScale->Js.Array2.mapi((color, i) => {
      let x = i * legendWidth / config.colorScale->Js.Array2.length

      `<rect x="${x->Belt.Int.toString}" y="20" width="${(legendWidth / config.colorScale->Js.Array2.length)->Belt.Int.toString}" height="${legendHeight->Belt.Int.toString}" fill="${color}" />`
    })->Js.Array2.joinWith("\n")

    let labels = `
      <text x="0" y="15" font-size="12">${minValue->Js.Float.toString}</text>
      <text x="${(legendWidth - 30)->Belt.Int.toString}" y="15" font-size="12">${maxValue->Js.Float.toString}</text>
    `

    svg ++ "\n" ++ colorStops ++ "\n" ++ labels ++ "\n</svg>"
  }
}

/**
 * Export geographic visualization as JSON
 */
let exportGeoData = (data: array<geoDataPoint>): string => {
  let features = data->Js.Array2.map(point => {
    Js.Dict.fromArray([
      ("type", Js.Json.string("Feature")),
      ("properties", Js.Json.object_(Js.Dict.fromArray([
        ("country", Js.Json.string(point.country)),
        ("code", Js.Json.string(point.countryCode)),
        ("value", Js.Json.number(point.value)),
      ]))),
      ("geometry", Js.Json.object_(Js.Dict.fromArray([
        ("type", Js.Json.string("Point")),
        ("coordinates", Js.Json.array([
          Js.Json.number(point.lon),
          Js.Json.number(point.lat),
        ])),
      ]))),
    ])
  })

  let geoJson = Js.Dict.fromArray([
    ("type", Js.Json.string("FeatureCollection")),
    ("features", Js.Json.array(features->Js.Array2.map(Js.Json.object_))),
  ])

  Js.Json.stringifyAny(Js.Json.object_(geoJson))->Belt.Option.getWithDefault("{}")
}
