// SPDX-License-Identifier: MPL-2.0
// SPDX-FileCopyrightText: 2024-2026 Hyperpolymath Contributors

/**
 * uno-bridge.js - JavaScript Bridge to LibreOffice UNO API
 *
 * This file runs in LibreOffice's Rhino JavaScript engine and provides
 * a bridge between ReScript code and the Java-based UNO API.
 *
 * Compatible with: LibreOffice 7.0+ (Rhino JS engine, ES5)
 * UNO Reference: https://api.libreoffice.org/
 */

/* global XSCRIPTCONTEXT, Packages, importClass */

// ============================================================================
// UNO Imports (Java classes via Rhino)
// ============================================================================

importClass(Packages.com.sun.star.sheet.XSpreadsheet);
importClass(Packages.com.sun.star.sheet.XSpreadsheetDocument);
importClass(Packages.com.sun.star.sheet.XSpreadsheets);
importClass(Packages.com.sun.star.table.XCell);
importClass(Packages.com.sun.star.table.XCellRange);
importClass(Packages.com.sun.star.table.CellContentType);
importClass(Packages.com.sun.star.sheet.XSpreadsheetView);
importClass(Packages.com.sun.star.frame.XModel);
importClass(Packages.com.sun.star.frame.XController);
importClass(Packages.com.sun.star.uno.UnoRuntime);
importClass(Packages.com.sun.star.beans.XPropertySet);
importClass(Packages.com.sun.star.container.XIndexAccess);
importClass(Packages.com.sun.star.container.XNameAccess);
importClass(Packages.com.sun.star.container.XNamed);

// ============================================================================
// Context Access
// ============================================================================

/**
 * Get the current spreadsheet document
 * @returns {XSpreadsheetDocument} The active document
 */
function getDocument() {
  if (typeof XSCRIPTCONTEXT === 'undefined') {
    throw new Error('UNO context not available - must run inside LibreOffice');
  }

  var document = XSCRIPTCONTEXT.getDocument();
  return UnoRuntime.queryInterface(
    Packages.com.sun.star.sheet.XSpreadsheetDocument,
    document
  );
}

/**
 * Get the active spreadsheet
 * @returns {XSpreadsheet} The active sheet
 */
function getActiveSheet() {
  var document = getDocument();
  var controller = document.getCurrentController();
  var view = UnoRuntime.queryInterface(
    Packages.com.sun.star.sheet.XSpreadsheetView,
    controller
  );
  return view.getActiveSheet();
}

/**
 * Get all spreadsheets
 * @returns {XSpreadsheets} The sheets collection
 */
function getSheets() {
  var document = getDocument();
  return document.getSheets();
}

// ============================================================================
// Cell Address Parsing
// ============================================================================

/**
 * Parse A1-style cell address to column and row indices
 * @param {string} address - Cell address (e.g., "A1", "B2", "AA10")
 * @returns {{col: number, row: number}}
 */
function parseCellAddress(address) {
  var col = 0;
  var row = 0;
  var i = 0;

  // Parse column letters (A=0, B=1, ..., Z=25, AA=26, ...)
  while (i < address.length && address.charCodeAt(i) >= 65 && address.charCodeAt(i) <= 90) {
    col = col * 26 + (address.charCodeAt(i) - 65 + 1);
    i++;
  }
  col = col - 1; // Convert to 0-based

  // Parse row number
  row = parseInt(address.substring(i), 10) - 1; // Convert to 0-based

  return { col: col, row: row };
}

/**
 * Convert column index to letter (0 -> A, 25 -> Z, 26 -> AA)
 * @param {number} col - Column index (0-based)
 * @returns {string} Column letter
 */
function colIndexToLetter(col) {
  var letter = '';
  var temp = col;

  while (temp >= 0) {
    letter = String.fromCharCode((temp % 26) + 65) + letter;
    temp = Math.floor(temp / 26) - 1;
  }

  return letter;
}

/**
 * Convert col/row indices to A1-style address
 * @param {number} col - Column index (0-based)
 * @param {number} row - Row index (0-based)
 * @returns {string} Cell address (e.g., "A1")
 */
function cellIndicesToAddress(col, row) {
  return colIndexToLetter(col) + (row + 1);
}

// ============================================================================
// Cell Value Conversion
// ============================================================================

/**
 * Get cell value and type
 * @param {XCell} cell - The cell object
 * @returns {{value: *, type: string}}
 */
function getCellValueAndType(cell) {
  var contentType = cell.getType();

  switch (contentType.getValue()) {
    case CellContentType.EMPTY_value:
      return { value: null, type: 'null' };

    case CellContentType.VALUE_value:
      return { value: cell.getValue(), type: 'number' };

    case CellContentType.TEXT_value:
      return { value: cell.getString(), type: 'string' };

    case CellContentType.FORMULA_value:
      // Return the calculated value, not the formula
      var valueType = cell.getType();
      if (valueType.getValue() === CellContentType.VALUE_value) {
        return { value: cell.getValue(), type: 'number' };
      } else {
        return { value: cell.getString(), type: 'string' };
      }

    default:
      return { value: null, type: 'undefined' };
  }
}

/**
 * Set cell value based on type
 * @param {XCell} cell - The cell object
 * @param {*} value - The value to set
 * @param {string} type - The value type
 */
function setCellValue(cell, value, type) {
  switch (type) {
    case 'string':
      cell.setString(String(value));
      break;

    case 'number':
      cell.setValue(Number(value));
      break;

    case 'boolean':
      cell.setValue(value ? 1 : 0);
      break;

    case 'null':
    case 'undefined':
      cell.setString('');
      break;

    default:
      cell.setString(String(value));
  }
}

// ============================================================================
// Bridge Functions (Called from ReScript)
// ============================================================================

/**
 * Check if UNO context is ready
 * @returns {boolean}
 */
function UNO_isReady() {
  try {
    getDocument();
    return true;
  } catch (e) {
    return false;
  }
}

/**
 * Get cell value at address
 * @param {string} address - Cell address (e.g., "A1")
 * @returns {{value: *, type: string}}
 */
function UNO_getCellValue(address) {
  var sheet = getActiveSheet();
  var pos = parseCellAddress(address);
  var cell = sheet.getCellByPosition(pos.col, pos.row);

  return getCellValueAndType(cell);
}

/**
 * Set cell value at address
 * @param {string} address - Cell address
 * @param {*} value - Value to set
 * @param {string} type - Value type
 */
function UNO_setCellValue(address, value, type) {
  var sheet = getActiveSheet();
  var pos = parseCellAddress(address);
  var cell = sheet.getCellByPosition(pos.col, pos.row);

  setCellValue(cell, value, type);
}

/**
 * Get range of cells
 * @param {string} startAddress - Start cell address
 * @param {string} endAddress - End cell address
 * @returns {Array<Array<{value: *, type: string}>>}
 */
function UNO_getRange(startAddress, endAddress) {
  var sheet = getActiveSheet();
  var start = parseCellAddress(startAddress);
  var end = parseCellAddress(endAddress);

  var range = sheet.getCellRangeByPosition(
    start.col,
    start.row,
    end.col,
    end.row
  );

  var result = [];
  var numRows = end.row - start.row + 1;
  var numCols = end.col - start.col + 1;

  for (var row = 0; row < numRows; row++) {
    var rowData = [];
    for (var col = 0; col < numCols; col++) {
      var cell = range.getCellByPosition(col, row);
      rowData.push(getCellValueAndType(cell));
    }
    result.push(rowData);
  }

  return result;
}

/**
 * Set range of cells
 * @param {string} startAddress - Start cell address
 * @param {Array<Array<{value: *, type: string}>>} matrix - 2D array of values
 */
function UNO_setRange(startAddress, matrix) {
  var sheet = getActiveSheet();
  var start = parseCellAddress(startAddress);

  var numRows = matrix.length;
  var numCols = matrix[0].length;

  var range = sheet.getCellRangeByPosition(
    start.col,
    start.row,
    start.col + numCols - 1,
    start.row + numRows - 1
  );

  for (var row = 0; row < numRows; row++) {
    for (var col = 0; col < numCols; col++) {
      var cell = range.getCellByPosition(col, row);
      var cellData = matrix[row][col];
      setCellValue(cell, cellData.value, cellData.type);
    }
  }
}

/**
 * Clear range of cells
 * @param {string} startAddress - Start cell address
 * @param {string} endAddress - End cell address
 */
function UNO_clearRange(startAddress, endAddress) {
  var sheet = getActiveSheet();
  var start = parseCellAddress(startAddress);
  var end = parseCellAddress(endAddress);

  var range = sheet.getCellRangeByPosition(
    start.col,
    start.row,
    end.col,
    end.row
  );

  var numRows = end.row - start.row + 1;
  var numCols = end.col - start.col + 1;

  for (var row = 0; row < numRows; row++) {
    for (var col = 0; col < numCols; col++) {
      var cell = range.getCellByPosition(col, row);
      cell.setString('');
    }
  }
}

/**
 * Get all sheet names
 * @returns {Array<string>}
 */
function UNO_getSheetNames() {
  var sheets = getSheets();
  var names = sheets.getElementNames();
  var result = [];

  for (var i = 0; i < names.length; i++) {
    result.push(names[i]);
  }

  return result;
}

/**
 * Get active sheet name
 * @returns {string}
 */
function UNO_getActiveSheetName() {
  var sheet = getActiveSheet();
  var named = UnoRuntime.queryInterface(
    Packages.com.sun.star.container.XNamed,
    sheet
  );
  return named.getName();
}

/**
 * Create new sheet
 * @param {string} name - Sheet name
 */
function UNO_createSheet(name) {
  var sheets = getSheets();
  var count = sheets.getCount();

  // Check if sheet with this name already exists
  if (sheets.hasByName(name)) {
    throw new Error('Sheet with name "' + name + '" already exists');
  }

  sheets.insertNewByName(name, count);
}

/**
 * Delete sheet
 * @param {string} name - Sheet name
 */
function UNO_deleteSheet(name) {
  var sheets = getSheets();

  if (!sheets.hasByName(name)) {
    throw new Error('Sheet with name "' + name + '" does not exist');
  }

  sheets.removeByName(name);
}

/**
 * Get selected range address
 * @returns {string} Range address (e.g., "A1:B10")
 */
function UNO_getSelectedRange() {
  var document = getDocument();
  var controller = document.getCurrentController();
  var selection = controller.getSelection();

  // Get first selected range
  var range = UnoRuntime.queryInterface(
    Packages.com.sun.star.table.XCellRange,
    selection
  );

  if (!range) {
    return 'A1';
  }

  var rangeAddress = range.getRangeAddress();

  var startCell = cellIndicesToAddress(
    rangeAddress.StartColumn,
    rangeAddress.StartRow
  );
  var endCell = cellIndicesToAddress(
    rangeAddress.EndColumn,
    rangeAddress.EndRow
  );

  return startCell + ':' + endCell;
}

/**
 * Set selected range
 * @param {string} rangeAddress - Range address (e.g., "A1:B10")
 */
function UNO_setSelectedRange(rangeAddress) {
  var parts = rangeAddress.split(':');
  var startAddress = parts[0];
  var endAddress = parts.length > 1 ? parts[1] : startAddress;

  var start = parseCellAddress(startAddress);
  var end = parseCellAddress(endAddress);

  var sheet = getActiveSheet();
  var range = sheet.getCellRangeByPosition(
    start.col,
    start.row,
    end.col,
    end.row
  );

  var document = getDocument();
  var controller = document.getCurrentController();
  controller.select(range);
}

/**
 * Show notification/message box
 * @param {string} message - Message to display
 * @param {string} title - Dialog title
 */
function UNO_showNotification(message, title) {
  var toolkit = XSCRIPTCONTEXT.getComponentContext()
    .getServiceManager()
    .createInstanceWithContext(
      'com.sun.star.awt.Toolkit',
      XSCRIPTCONTEXT.getComponentContext()
    );

  var msgBox = UnoRuntime.queryInterface(
    Packages.com.sun.star.awt.XMessageBox,
    toolkit.createMessageBox(
      null,
      Packages.com.sun.star.awt.MessageBoxType.INFOBOX,
      Packages.com.sun.star.awt.MessageBoxButtons.BUTTONS_OK,
      title || 'Notification',
      message
    )
  );

  msgBox.execute();
}

/**
 * Recalculate spreadsheet
 */
function UNO_recalculate() {
  var document = getDocument();
  document.calculateAll();
}

// ============================================================================
// Custom Functions Registry
// ============================================================================

var customFunctions = {};

/**
 * Register custom function
 * @param {string} name - Function name
 * @param {Function} impl - Implementation function
 */
function UNO_registerFunction(name, impl) {
  customFunctions[name] = impl;
}

/**
 * Call registered custom function
 * @param {string} name - Function name
 * @param {Array} args - Function arguments
 * @returns {*} Function result
 */
function UNO_callFunction(name, args) {
  if (!customFunctions.hasOwnProperty(name)) {
    throw new Error('Function "' + name + '" not registered');
  }

  return customFunctions[name].apply(null, args);
}

// ============================================================================
// Export Bridge API (Make functions accessible to ReScript)
// ============================================================================

// In LibreOffice Rhino, functions are automatically global
// No explicit export needed
