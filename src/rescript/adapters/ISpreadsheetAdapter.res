// SPDX-License-Identifier: MPL-2.0
// SPDX-FileCopyrightText: 2024-2026 Hyperpolymath Contributors

/**
 * ISpreadsheetAdapter - Cross-Platform Abstraction Interface
 *
 * Unified interface for both Microsoft Excel (Office.js) and LibreOffice Calc (UNO API).
 * Allows single codebase to work across both platforms.
 */

// Type definitions
type cellAddress = string
type rangeAddress = string

type cellValue =
  | String(string)
  | Number(float)
  | Boolean(bool)
  | Date(Js.Date.t)
  | Null
  | Undefined

type cellMatrix = array<array<cellValue>>

type parameterType = [#string | #number | #boolean | #range]
type returnType = [#string | #number | #boolean | #range]

type functionParameter = {
  name: string,
  description: string,
  @as("type") type_: parameterType,
}

type customFunctionMetadata = {
  name: string,
  description: string,
  parameters: array<functionParameter>,
  returnType: returnType,
}

type dialogOptions = {
  title: string,
  width: option<int>,
  height: option<int>,
}

type taskPaneOptions = {
  title: string,
  url: string,
  width: option<int>,
}

type platform = [#excel | #libreoffice | #web | #unknown]

type notificationType = [#info | #warning | #error]

// Main adapter interface
module type Adapter = {
  // Platform detection
  let getPlatform: unit => platform
  let isReady: unit => promise<bool>

  // Cell operations
  let getCellValue: cellAddress => promise<cellValue>
  let setCellValue: (cellAddress, cellValue) => promise<unit>
  let getRange: (cellAddress, cellAddress) => promise<cellMatrix>
  let setRange: (cellAddress, cellMatrix) => promise<unit>
  let clearRange: (cellAddress, cellAddress) => promise<unit>

  // Custom functions
  let registerFunction: (
    customFunctionMetadata,
    array<'a> => 'b,
  ) => unit
  let callFunction: (string, array<'a>) => promise<'b>

  // Events
  let onSelectionChange: (cellAddress => unit) => unit => unit
  let onCalculate: (unit => unit) => unit => unit
  let onSheetChange: (string => unit) => unit => unit

  // UI
  let showDialog: (string, dialogOptions) => promise<unit>
  let showTaskPane: (string, taskPaneOptions) => promise<unit>
  let showNotification: (string, notificationType) => promise<unit>

  // Sheets
  let getSheetNames: unit => promise<array<string>>
  let getActiveSheetName: unit => promise<string>
  let createSheet: string => promise<unit>
  let deleteSheet: string => promise<unit>

  // Utilities
  let getSelectedRange: unit => promise<rangeAddress>
  let setSelectedRange: rangeAddress => promise<unit>
  let batch: (unit => promise<'a>) => promise<'a>
  let recalculate: unit => promise<unit>
}

// Platform detection utilities
@val @scope("window")
external officeExists: option<'a> = "Office"

@val @scope("window")
external xscriptcontextExists: option<'a> = "XSCRIPTCONTEXT"

@val @scope("window")
external windowExists: option<'a> = "window"

let detectPlatform = (): platform => {
  switch (officeExists, xscriptcontextExists, windowExists) {
  | (Some(_), _, _) => #excel
  | (_, Some(_), _) => #libreoffice
  | (_, _, Some(_)) => #web
  | _ => #unknown
  }
}

// Factory function to create appropriate adapter
exception UnknownPlatform(string)

let createAdapter = (): module(Adapter) => {
  switch detectPlatform() {
  | #excel =>
    module(OfficeJsAdapter)
  | #libreoffice =>
    module(UnoAdapter)
  | #web | #unknown =>
    raise(UnknownPlatform("Unknown platform - neither Office.js nor UNO detected"))
  }
}
