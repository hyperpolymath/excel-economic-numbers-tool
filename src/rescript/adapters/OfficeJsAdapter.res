// SPDX-License-Identifier: MPL-2.0
// SPDX-FileCopyrightText: 2024-2026 Hyperpolymath Contributors

/**
 * OfficeJsAdapter - Microsoft Excel/Office.js Platform Adapter
 *
 * Implements ISpreadsheetAdapter interface using Office.js API.
 * Supports Excel on Windows, macOS, Web, and Mobile.
 *
 * Reference: https://learn.microsoft.com/en-us/office/dev/add-ins/reference/overview/excel-add-ins-reference-overview
 */

open ISpreadsheetAdapter

// ============================================================================
// Office.js Bindings
// ============================================================================

// Core Office.js API
@val @scope(("window", "Office"))
external onReady: (unit => unit) => unit = "onReady"

@val @scope(("window", "Office", "context"))
external officeContext: 'a = "this"

@val @scope(("window", "Office", "context", "ui"))
external displayDialogAsync: (string, 'options, ('result, 'error) => unit) => unit = "displayDialogAsync"

@module("@microsoft/office-js") @scope("Excel")
external excelRun: ('context => promise<'a>) => promise<'a> = "run"

// Excel Context Types
module Context = {
  type t

  @send external sync: t => promise<unit> = "sync"

  type workbook
  @get external workbook: t => workbook = "workbook"
}

module Workbook = {
  type t = Context.workbook

  type worksheets
  @get external worksheets: t => worksheets = "worksheets"

  @send external getActiveWorksheet: t => promise<Worksheet.t> = "getActiveWorksheet"
}

module Worksheet = {
  type t

  @send external getRange: (t, string) => Range.t = "getRange"
  @send external getRangeByIndexes: (t, int, int, int, int) => Range.t = "getRangeByIndexes"
  @send external load: (t, string) => t = "load"
  @get external name: t => string = "name"
  @send external activate: t => unit = "activate"
  @send external delete: t => unit = "delete"
}

module Worksheets = {
  type t

  @send external load: (t, string) => t = "load"
  @send external getItemAt: (t, int) => Worksheet.t = "getItemAt"
  @send external add: (t, option<string>) => Worksheet.t = "add"
  @get external items: t => array<Worksheet.t> = "items"
  @get external count: t => int = "count"
}

module Range = {
  type t

  @send external load: (t, string) => t = "load"
  @get external values: t => array<array<'a>> = "values"
  @set external setValues: (t, array<array<'a>>) => unit = "values"
  @send external clear: t => unit = "clear"
  @get external address: t => string = "address"
  @send external select: t => unit = "select"
  @send external getCell: (t, int, int) => t = "getCell"

  type valueTypes
  @get external valueTypes: t => array<array<string>> = "valueTypes"
}

// Event bindings
module Events = {
  type eventHandler<'a> = 'a => unit
  type unsubscribe = unit => unit

  @send external onSelectionChanged: (Context.workbook, eventHandler<'a>) => unsubscribe = "onSelectionChanged"
  @send external onCalculated: (Context.workbook, eventHandler<'a>) => unsubscribe = "onCalculated"
  @send external onWorksheetChanged: (Context.workbook, eventHandler<'a>) => unsubscribe = "onWorksheetChanged"
}

// Custom Functions
module CustomFunctions = {
  @val @scope(("window", "CustomFunctions"))
  external associate: (string, 'fn) => unit = "associate"
}

// ============================================================================
// State Management
// ============================================================================

// Store registered custom functions
let registeredFunctions: Js.Dict.t<array<'a> => 'b> = Js.Dict.empty()

// Ready state
let ready = ref(false)

// ============================================================================
// Helper Functions
// ============================================================================

// Parse cell address (e.g., "A1" -> (0, 0))
let parseCellAddress = (address: cellAddress): (int, int) => {
  let col = ref(0)
  let row = ref(0)

  let chars = Js.String2.split(address, "")
  let digitStart = ref(0)

  // Parse column letters
  for i in 0 to Js.Array.length(chars) - 1 {
    let char = chars[i]
    if char >= "A" && char <= "Z" {
      col := col.contents * 26 + (Js.String2.charCodeAt(char, 0) - 65.0)->Belt.Float.toInt
    } else {
      digitStart := i
      break
    }
  }

  // Parse row number
  let rowStr = Js.Array.sliceFrom(digitStart.contents, chars)->Js.Array2.joinWith("")
  row := Belt.Int.fromString(rowStr)->Belt.Option.getWithDefault(1) - 1

  (row.contents, col.contents)
}

// Convert cellValue to JavaScript value
let cellValueToJs = (value: cellValue): 'a => {
  switch value {
  | String(s) => s->Obj.magic
  | Number(n) => n->Obj.magic
  | Boolean(b) => b->Obj.magic
  | Date(d) => d->Obj.magic
  | Null => Js.Nullable.null->Obj.magic
  | Undefined => Js.Nullable.undefined->Obj.magic
  }
}

// Convert JavaScript value to cellValue
let jsToCellValue = (value: 'a): cellValue => {
  let typeStr = Js.typeof(value)

  switch typeStr {
  | "string" => String(value->Obj.magic)
  | "number" => Number(value->Obj.magic)
  | "boolean" => Boolean(value->Obj.magic)
  | "object" => {
      if Js.Nullable.isNullable(value->Obj.magic) {
        Null
      } else if Js.Date.getTime(value->Obj.magic)->Js.Float.isNaN == false {
        Date(value->Obj.magic)
      } else {
        Null
      }
    }
  | _ => Undefined
  }
}

// Convert 2D array to cellMatrix
let arrayToMatrix = (arr: array<array<'a>>): cellMatrix => {
  arr->Js.Array2.map(row => {
    row->Js.Array2.map(jsToCellValue)
  })
}

// Convert cellMatrix to 2D array
let matrixToArray = (matrix: cellMatrix): array<array<'a>> => {
  matrix->Js.Array2.map(row => {
    row->Js.Array2.map(cellValueToJs)
  })
}

// Format range address from two cell addresses
let formatRangeAddress = (start: cellAddress, end: cellAddress): string => {
  `${start}:${end}`
}

// ============================================================================
// Adapter Implementation
// ============================================================================

// Platform detection
let getPlatform = (): platform => #excel

let isReady = (): promise<bool> => {
  Promise.make((resolve, _reject) => {
    if ready.contents {
      resolve(. true)
    } else {
      onReady(() => {
        ready := true
        resolve(. true)
      })
    }
  })
}

// Cell operations
let getCellValue = (address: cellAddress): promise<cellValue> => {
  excelRun(context => {
    let worksheet = Context.workbook(context)->Workbook.getActiveWorksheet

    worksheet->Promise.then_(sheet => {
      let range = Worksheet.getRange(sheet, address)
      let _ = Range.load(range, "values,valueTypes")

      Context.sync(context)->Promise.then_(_ => {
        let values = Range.values(range)
        let value = values[0][0]
        Promise.resolve(jsToCellValue(value))
      })
    })
  })
}

let setCellValue = (address: cellAddress, value: cellValue): promise<unit> => {
  excelRun(context => {
    let worksheet = Context.workbook(context)->Workbook.getActiveWorksheet

    worksheet->Promise.then_(sheet => {
      let range = Worksheet.getRange(sheet, address)
      Range.setValues(range, [[cellValueToJs(value)]])

      Context.sync(context)
    })
  })
}

let getRange = (startAddress: cellAddress, endAddress: cellAddress): promise<cellMatrix> => {
  let rangeAddress = formatRangeAddress(startAddress, endAddress)

  excelRun(context => {
    let worksheet = Context.workbook(context)->Workbook.getActiveWorksheet

    worksheet->Promise.then_(sheet => {
      let range = Worksheet.getRange(sheet, rangeAddress)
      let _ = Range.load(range, "values")

      Context.sync(context)->Promise.then_(_ => {
        let values = Range.values(range)
        Promise.resolve(arrayToMatrix(values))
      })
    })
  })
}

let setRange = (startAddress: cellAddress, matrix: cellMatrix): promise<unit> => {
  excelRun(context => {
    let worksheet = Context.workbook(context)->Workbook.getActiveWorksheet

    worksheet->Promise.then_(sheet => {
      let range = Worksheet.getRange(sheet, startAddress)
      let jsMatrix = matrixToArray(matrix)
      Range.setValues(range, jsMatrix)

      Context.sync(context)
    })
  })
}

let clearRange = (startAddress: cellAddress, endAddress: cellAddress): promise<unit> => {
  let rangeAddress = formatRangeAddress(startAddress, endAddress)

  excelRun(context => {
    let worksheet = Context.workbook(context)->Workbook.getActiveWorksheet

    worksheet->Promise.then_(sheet => {
      let range = Worksheet.getRange(sheet, rangeAddress)
      Range.clear(range)

      Context.sync(context)
    })
  })
}

// Custom functions
let registerFunction = (
  metadata: customFunctionMetadata,
  impl: array<'a> => 'b,
): unit => {
  // Store function implementation
  Js.Dict.set(registeredFunctions, metadata.name, impl)

  // Associate with Office.js Custom Functions
  CustomFunctions.associate(metadata.name, impl)
}

let callFunction = (name: string, args: array<'a>): promise<'b> => {
  Promise.make((resolve, reject) => {
    switch Js.Dict.get(registeredFunctions, name) {
    | Some(fn) => {
        let result = fn(args)
        resolve(. result)
      }
    | None => reject(. Js.Exn.raiseError(`Function ${name} not registered`))
    }
  })
}

// Events
let onSelectionChange = (handler: cellAddress => unit): (unit => unit) => {
  let unsubscribe = ref(None)

  let _ = excelRun(context => {
    let workbook = Context.workbook(context)

    let eventHandler = (event) => {
      let address = event["address"]->Obj.magic
      handler(address)
    }

    let unsub = Events.onSelectionChanged(workbook, eventHandler)
    unsubscribe := Some(unsub)

    Promise.resolve()
  })

  () => {
    switch unsubscribe.contents {
    | Some(unsub) => unsub()
    | None => ()
    }
  }
}

let onCalculate = (handler: unit => unit): (unit => unit) => {
  let unsubscribe = ref(None)

  let _ = excelRun(context => {
    let workbook = Context.workbook(context)

    let eventHandler = (_event) => {
      handler()
    }

    let unsub = Events.onCalculated(workbook, eventHandler)
    unsubscribe := Some(unsub)

    Promise.resolve()
  })

  () => {
    switch unsubscribe.contents {
    | Some(unsub) => unsub()
    | None => ()
    }
  }
}

let onSheetChange = (handler: string => unit): (unit => unit) => {
  let unsubscribe = ref(None)

  let _ = excelRun(context => {
    let workbook = Context.workbook(context)

    let eventHandler = (event) => {
      let sheetName = event["worksheetId"]->Obj.magic
      handler(sheetName)
    }

    let unsub = Events.onWorksheetChanged(workbook, eventHandler)
    unsubscribe := Some(unsub)

    Promise.resolve()
  })

  () => {
    switch unsubscribe.contents {
    | Some(unsub) => unsub()
    | None => ()
    }
  }
}

// UI operations
let showDialog = (url: string, options: dialogOptions): promise<unit> => {
  Promise.make((resolve, _reject) => {
    let jsOptions = {
      "width": options.width->Belt.Option.getWithDefault(400),
      "height": options.height->Belt.Option.getWithDefault(300),
      "displayInIframe": true,
    }

    displayDialogAsync(url, jsOptions, (_result, _error) => {
      resolve(. ())
    })
  })
}

let showTaskPane = (_url: string, _options: taskPaneOptions): promise<unit> => {
  // Task pane is automatically shown when add-in loads
  // This is a no-op for Excel
  Promise.resolve()
}

let showNotification = (message: string, _notificationType: notificationType): promise<unit> => {
  // Use Office.context.ui.displayDialogAsync for notifications
  Promise.make((resolve, _reject) => {
    let html = `<html><body><h2>${message}</h2></body></html>`
    let options = {"width": 300, "height": 150, "displayInIframe": true}

    displayDialogAsync(html, options, (_result, _error) => {
      resolve(. ())
    })
  })
}

// Sheet operations
let getSheetNames = (): promise<array<string>> => {
  excelRun(context => {
    let workbook = Context.workbook(context)
    let sheets = Workbook.worksheets(workbook)
    let _ = Worksheets.load(sheets, "name")

    Context.sync(context)->Promise.then_(_ => {
      let items = Worksheets.items(sheets)
      let names = items->Js.Array2.map(sheet => Worksheet.name(sheet))
      Promise.resolve(names)
    })
  })
}

let getActiveSheetName = (): promise<string> => {
  excelRun(context => {
    let workbook = Context.workbook(context)

    Workbook.getActiveWorksheet(workbook)->Promise.then_(sheet => {
      let _ = Worksheet.load(sheet, "name")

      Context.sync(context)->Promise.then_(_ => {
        Promise.resolve(Worksheet.name(sheet))
      })
    })
  })
}

let createSheet = (name: string): promise<unit> => {
  excelRun(context => {
    let workbook = Context.workbook(context)
    let sheets = Workbook.worksheets(workbook)
    let _ = Worksheets.add(sheets, Some(name))

    Context.sync(context)
  })
}

let deleteSheet = (name: string): promise<unit> => {
  excelRun(context => {
    let workbook = Context.workbook(context)
    let sheets = Workbook.worksheets(workbook)
    let _ = Worksheets.load(sheets, "name")

    Context.sync(context)->Promise.then_(_ => {
      let items = Worksheets.items(sheets)
      let targetSheet = items->Js.Array2.find(sheet => Worksheet.name(sheet) == name)

      switch targetSheet {
      | Some(sheet) => {
          Worksheet.delete(sheet)
          Context.sync(context)
        }
      | None => Promise.resolve()
      }
    })
  })
}

// Utility operations
let getSelectedRange = (): promise<rangeAddress> => {
  excelRun(context => {
    let worksheet = Context.workbook(context)->Workbook.getActiveWorksheet

    worksheet->Promise.then_(sheet => {
      // Get selected range (Excel tracks this internally)
      let range = Worksheet.getRange(sheet, "")
      let _ = Range.load(range, "address")

      Context.sync(context)->Promise.then_(_ => {
        Promise.resolve(Range.address(range))
      })
    })
  })
}

let setSelectedRange = (rangeAddress: rangeAddress): promise<unit> => {
  excelRun(context => {
    let worksheet = Context.workbook(context)->Workbook.getActiveWorksheet

    worksheet->Promise.then_(sheet => {
      let range = Worksheet.getRange(sheet, rangeAddress)
      Range.select(range)

      Context.sync(context)
    })
  })
}

let batch = (fn: unit => promise<'a>): promise<'a> => {
  // Excel.run already provides batching via context.sync()
  fn()
}

let recalculate = (): promise<unit> => {
  excelRun(context => {
    // Excel automatically recalculates on data change
    // Force sync to ensure all calculations complete
    Context.sync(context)
  })
}
