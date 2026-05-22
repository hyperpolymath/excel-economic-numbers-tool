// SPDX-License-Identifier: MPL-2.0
// SPDX-FileCopyrightText: 2024-2026 Hyperpolymath Contributors

/**
 * UnoAdapter - LibreOffice Calc/UNO Platform Adapter
 *
 * Implements ISpreadsheetAdapter interface using UNO API via JavaScript bridge.
 * Supports LibreOffice Calc 7.0+ on Windows, macOS, and Linux.
 *
 * Architecture: ReScript → uno-bridge.js → UNO Java API → LibreOffice Calc
 */

open ISpreadsheetAdapter

// ============================================================================
// Bridge Function Bindings
// ============================================================================

// These functions are provided by uno-bridge.js running in Rhino

type cellValueAndType = {
  value: Js.Nullable.t<'a>,
  @as("type") type_: string,
}

// Context
@val external unoIsReady: unit => bool = "UNO_isReady"

// Cell operations
@val external unoGetCellValue: cellAddress => cellValueAndType = "UNO_getCellValue"
@val external unoSetCellValue: (cellAddress, 'a, string) => unit = "UNO_setCellValue"

// Range operations
@val external unoGetRange: (cellAddress, cellAddress) => array<array<cellValueAndType>> = "UNO_getRange"
@val external unoSetRange: (cellAddress, array<array<cellValueAndType>>) => unit = "UNO_setRange"
@val external unoClearRange: (cellAddress, cellAddress) => unit = "UNO_clearRange"

// Sheet operations
@val external unoGetSheetNames: unit => array<string> = "UNO_getSheetNames"
@val external unoGetActiveSheetName: unit => string = "UNO_getActiveSheetName"
@val external unoCreateSheet: string => unit = "UNO_createSheet"
@val external unoDeleteSheet: string => unit = "UNO_deleteSheet"

// Selection
@val external unoGetSelectedRange: unit => string = "UNO_getSelectedRange"
@val external unoSetSelectedRange: string => unit = "UNO_setSelectedRange"

// Utilities
@val external unoShowNotification: (string, string) => unit = "UNO_showNotification"
@val external unoRecalculate: unit => unit = "UNO_recalculate"

// Custom functions
@val external unoRegisterFunction: (string, array<'a> => 'b) => unit = "UNO_registerFunction"
@val external unoCallFunction: (string, array<'a>) => 'b = "UNO_callFunction"

// ============================================================================
// Helper Functions
// ============================================================================

// Convert bridge cellValueAndType to cellValue
let bridgeToCellValue = (data: cellValueAndType): cellValue => {
  switch data.type_ {
  | "string" => String(data.value->Js.Nullable.toOption->Belt.Option.getWithDefault("")->Obj.magic)
  | "number" => Number(data.value->Js.Nullable.toOption->Belt.Option.getWithDefault(0.0)->Obj.magic)
  | "boolean" => Boolean(data.value->Js.Nullable.toOption->Belt.Option.getWithDefault(false)->Obj.magic)
  | "null" => Null
  | _ => Undefined
  }
}

// Convert cellValue to bridge format (value + type)
let cellValueToBridge = (value: cellValue): (Js.Nullable.t<'a>, string) => {
  switch value {
  | String(s) => (Js.Nullable.return(s->Obj.magic), "string")
  | Number(n) => (Js.Nullable.return(n->Obj.magic), "number")
  | Boolean(b) => (Js.Nullable.return(b->Obj.magic), "boolean")
  | Date(d) => {
      // Convert date to Excel serial number (days since 1899-12-30)
      let msPerDay = 86400000.0
      let excelEpoch = Js.Date.fromFloat(-2209161600000.0) // 1899-12-30
      let days = (Js.Date.getTime(d) -. Js.Date.getTime(excelEpoch)) /. msPerDay
      (Js.Nullable.return(days->Obj.magic), "number")
    }
  | Null => (Js.Nullable.null, "null")
  | Undefined => (Js.Nullable.undefined, "undefined")
  }
}

// Convert 2D bridge array to cellMatrix
let bridgeMatrixToCellMatrix = (bridge: array<array<cellValueAndType>>): cellMatrix => {
  bridge->Js.Array2.map(row => {
    row->Js.Array2.map(bridgeToCellValue)
  })
}

// Convert cellMatrix to 2D bridge array
let cellMatrixToBridgeMatrix = (matrix: cellMatrix): array<array<cellValueAndType>> => {
  matrix->Js.Array2.map(row => {
    row->Js.Array2.map(cellValue => {
      let (value, type_) = cellValueToBridge(cellValue)
      {value: value, type_: type_}
    })
  })
}

// Wrap synchronous bridge calls in promises (for interface compatibility)
let wrapSync = (fn: unit => 'a): promise<'a> => {
  Promise.resolve(fn())
}

// Format range address from two cell addresses
let formatRangeAddress = (start: cellAddress, end: cellAddress): string => {
  `${start}:${end}`
}

// Parse range address to (start, end)
let parseRangeAddress = (rangeAddr: string): (cellAddress, cellAddress) => {
  let parts = Js.String2.split(rangeAddr, ":")
  switch parts {
  | [start, end] => (start, end)
  | [single] => (single, single)
  | _ => ("A1", "A1")
  }
}

// ============================================================================
// State Management
// ============================================================================

// Event handlers storage
let selectionChangeHandlers: ref<array<cellAddress => unit>> = ref([])
let calculateHandlers: ref<array<unit => unit>> = ref([])
let sheetChangeHandlers: ref<array<string => unit>> = ref([])

// Custom functions registry
let registeredFunctions: Js.Dict.t<array<'a> => 'b> = Js.Dict.empty()

// ============================================================================
// Adapter Implementation
// ============================================================================

// Platform detection
let getPlatform = (): platform => #libreoffice

let isReady = (): promise<bool> => {
  wrapSync(() => unoIsReady())
}

// Cell operations
let getCellValue = (address: cellAddress): promise<cellValue> => {
  wrapSync(() => {
    let data = unoGetCellValue(address)
    bridgeToCellValue(data)
  })
}

let setCellValue = (address: cellAddress, value: cellValue): promise<unit> => {
  wrapSync(() => {
    let (jsValue, type_) = cellValueToBridge(value)
    unoSetCellValue(address, jsValue, type_)
  })
}

let getRange = (startAddress: cellAddress, endAddress: cellAddress): promise<cellMatrix> => {
  wrapSync(() => {
    let bridgeMatrix = unoGetRange(startAddress, endAddress)
    bridgeMatrixToCellMatrix(bridgeMatrix)
  })
}

let setRange = (startAddress: cellAddress, matrix: cellMatrix): promise<unit> => {
  wrapSync(() => {
    let bridgeMatrix = cellMatrixToBridgeMatrix(matrix)
    unoSetRange(startAddress, bridgeMatrix)
  })
}

let clearRange = (startAddress: cellAddress, endAddress: cellAddress): promise<unit> => {
  wrapSync(() => {
    unoClearRange(startAddress, endAddress)
  })
}

// Custom functions
let registerFunction = (
  metadata: customFunctionMetadata,
  impl: array<'a> => 'b,
): unit => {
  // Store in ReScript registry
  Js.Dict.set(registeredFunctions, metadata.name, impl)

  // Register with UNO bridge
  unoRegisterFunction(metadata.name, impl)
}

let callFunction = (name: string, args: array<'a>): promise<'b> => {
  Promise.make((resolve, reject) => {
    try {
      let result = unoCallFunction(name, args)
      resolve(. result)
    } catch {
    | Js.Exn.Error(e) =>
      switch Js.Exn.message(e) {
      | Some(msg) => reject(. Js.Exn.raiseError(msg))
      | None => reject(. Js.Exn.raiseError("Unknown error calling function"))
      }
    | _ => reject(. Js.Exn.raiseError("Unknown error"))
    }
  })
}

// Events
// Note: LibreOffice UNO events are more limited than Office.js
// These are simulated by polling or manual triggers

let onSelectionChange = (handler: cellAddress => unit): (unit => unit) => {
  // Add handler to registry
  selectionChangeHandlers := Js.Array2.concat(selectionChangeHandlers.contents, [handler])

  // Return unsubscribe function
  () => {
    selectionChangeHandlers := Js.Array2.filter(selectionChangeHandlers.contents, h => h !== handler)
  }
}

let onCalculate = (handler: unit => unit): (unit => unit) => {
  // Add handler to registry
  calculateHandlers := Js.Array2.concat(calculateHandlers.contents, [handler])

  // Return unsubscribe function
  () => {
    calculateHandlers := Js.Array2.filter(calculateHandlers.contents, h => h !== handler)
  }
}

let onSheetChange = (handler: string => unit): (unit => unit) => {
  // Add handler to registry
  sheetChangeHandlers := Js.Array2.concat(sheetChangeHandlers.contents, [handler])

  // Return unsubscribe function
  () => {
    sheetChangeHandlers := Js.Array2.filter(sheetChangeHandlers.contents, h => h !== handler)
  }
}

// Helper to trigger selection change events (called externally)
let triggerSelectionChange = (address: cellAddress): unit => {
  selectionChangeHandlers.contents->Js.Array2.forEach(handler => handler(address))
}

// Helper to trigger calculate events (called externally)
let triggerCalculate = (): unit => {
  calculateHandlers.contents->Js.Array2.forEach(handler => handler())
}

// Helper to trigger sheet change events (called externally)
let triggerSheetChange = (sheetName: string): unit => {
  sheetChangeHandlers.contents->Js.Array2.forEach(handler => handler(sheetName))
}

// UI operations
let showDialog = (url: string, options: dialogOptions): promise<unit> => {
  // UNO doesn't have built-in HTML dialog support like Office.js
  // Show notification instead
  wrapSync(() => {
    unoShowNotification(`Dialog: ${url}`, options.title)
  })
}

let showTaskPane = (_url: string, options: taskPaneOptions): promise<unit> => {
  // Task panes are not directly supported in LibreOffice
  // Show notification instead
  wrapSync(() => {
    unoShowNotification("Task pane opened", options.title)
  })
}

let showNotification = (message: string, notificationType: notificationType): promise<unit> => {
  wrapSync(() => {
    let title = switch notificationType {
    | #info => "Information"
    | #warning => "Warning"
    | #error => "Error"
    }
    unoShowNotification(message, title)
  })
}

// Sheet operations
let getSheetNames = (): promise<array<string>> => {
  wrapSync(() => unoGetSheetNames())
}

let getActiveSheetName = (): promise<string> => {
  wrapSync(() => unoGetActiveSheetName())
}

let createSheet = (name: string): promise<unit> => {
  wrapSync(() => unoCreateSheet(name))
}

let deleteSheet = (name: string): promise<unit> => {
  wrapSync(() => unoDeleteSheet(name))
}

// Utility operations
let getSelectedRange = (): promise<rangeAddress> => {
  wrapSync(() => unoGetSelectedRange())
}

let setSelectedRange = (rangeAddress: rangeAddress): promise<unit> => {
  wrapSync(() => unoSetSelectedRange(rangeAddress))
}

let batch = (fn: unit => promise<'a>): promise<'a> => {
  // UNO doesn't have built-in batching like Office.js
  // Just execute the function directly
  fn()
}

let recalculate = (): promise<unit> => {
  wrapSync(() => unoRecalculate())
}
