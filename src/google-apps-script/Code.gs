// SPDX-License-Identifier: PMPL-1.0-or-later
// Economic Toolkit Google Sheets Add-on

/**
 * Creates a menu entry in the Google Sheets UI.
 */
function onOpen() {
  SpreadsheetApp.getUi()
    .createAddonMenu()
    .addItem('Open Economic Toolkit', 'showSidebar')
    .addItem('Settings', 'showSettings')
    .addToUi();
}

/**
 * Runs when the add-on is installed.
 */
function onInstall() {
  onOpen();
}

/**
 * Opens the add-on sidebar.
 */
function showSidebar() {
  var html = HtmlService.createHtmlOutputFromFile('Sidebar')
    .setTitle('Economic Toolkit')
    .setWidth(300);
  SpreadsheetApp.getUi().showSidebar(html);
}

/**
 * Shows settings dialog.
 */
function showSettings() {
  var html = HtmlService.createHtmlOutputFromFile('Settings')
    .setWidth(400)
    .setHeight(300);
  SpreadsheetApp.getUi().showModalDialog(html, 'Economic Toolkit Settings');
}

/**
 * Custom function: Fetch data from FRED.
 * @param {string} seriesId The FRED series ID (e.g., "UNRATE")
 * @param {string} startDate Start date in YYYY-MM-DD format
 * @param {string} endDate End date in YYYY-MM-DD format
 * @return {Array<Array>} The series data
 * @customfunction
 */
function ECON_FRED(seriesId, startDate, endDate) {
  var apiUrl = getApiUrl();
  var apiKey = getApiKey();

  var url = apiUrl + '/api/v1/sources/fred/series/' + seriesId +
            '?start=' + startDate + '&end=' + endDate;

  var options = {
    'method': 'GET',
    'headers': apiKey ? {'Authorization': 'Bearer ' + apiKey} : {}
  };

  try {
    var response = UrlFetchApp.fetch(url, options);
    var data = JSON.parse(response.getContentText());

    if (data.observations) {
      var result = [['Date', 'Value']];
      data.observations.forEach(function(obs) {
        result.push([obs.date, obs.value]);
      });
      return result;
    }

    return [['Error', 'No data found']];
  } catch (e) {
    return [['Error', e.toString()]];
  }
}

/**
 * Custom function: Fetch data from World Bank.
 * @param {string} countryCode Country code (e.g., "USA")
 * @param {string} indicator Indicator code (e.g., "NY.GDP.MKTP.CD")
 * @param {number} startYear Start year
 * @param {number} endYear End year
 * @return {Array<Array>} The series data
 * @customfunction
 */
function ECON_WORLDBANK(countryCode, indicator, startYear, endYear) {
  var apiUrl = getApiUrl();
  var apiKey = getApiKey();

  var seriesId = countryCode + '/' + indicator;
  var url = apiUrl + '/api/v1/sources/worldbank/series/' + seriesId +
            '?start=' + startYear + '-01-01&end=' + endYear + '-12-31';

  var options = {
    'method': 'GET',
    'headers': apiKey ? {'Authorization': 'Bearer ' + apiKey} : {}
  };

  try {
    var response = UrlFetchApp.fetch(url, options);
    var data = JSON.parse(response.getContentText());

    if (data.observations) {
      var result = [['Year', 'Value']];
      data.observations.forEach(function(obs) {
        result.push([obs.date, obs.value]);
      });
      return result;
    }

    return [['Error', 'No data found']];
  } catch (e) {
    return [['Error', e.toString()]];
  }
}

/**
 * Custom function: Calculate Gini coefficient.
 * @param {Array<number>} values Income or wealth values
 * @return {number} Gini coefficient (0-1)
 * @customfunction
 */
function ECON_GINI(values) {
  if (!Array.isArray(values) || values.length === 0) {
    return '#ERROR!';
  }

  // Flatten if 2D array
  var flatValues = values.flat().filter(function(v) { return typeof v === 'number'; });

  if (flatValues.length < 2) {
    return '#ERROR!';
  }

  var sorted = flatValues.slice().sort(function(a, b) { return a - b; });
  var n = sorted.length;
  var sum = sorted.reduce(function(acc, val) { return acc + val; }, 0);

  var numerator = 0;
  for (var i = 0; i < n; i++) {
    numerator += (n - i) * sorted[i];
  }

  var gini = (2 * numerator) / (n * sum) - (n + 1) / n;
  return gini;
}

/**
 * Custom function: Calculate growth rate.
 * @param {Array<number>} values Time series values
 * @return {Array<number>} Growth rates as percentages
 * @customfunction
 */
function ECON_GROWTH_RATE(values) {
  if (!Array.isArray(values) || values.length < 2) {
    return '#ERROR!';
  }

  var flatValues = values.flat().filter(function(v) { return typeof v === 'number'; });

  var growthRates = [];
  for (var i = 1; i < flatValues.length; i++) {
    var rate = ((flatValues[i] - flatValues[i-1]) / flatValues[i-1]) * 100;
    growthRates.push([rate]);
  }

  return growthRates;
}

/**
 * Custom function: Calculate CAGR.
 * @param {number} beginValue Beginning value
 * @param {number} endValue Ending value
 * @param {number} periods Number of periods
 * @return {number} CAGR as percentage
 * @customfunction
 */
function ECON_CAGR(beginValue, endValue, periods) {
  if (beginValue <= 0 || endValue <= 0 || periods <= 0) {
    return '#ERROR!';
  }

  return (Math.pow(endValue / beginValue, 1 / periods) - 1) * 100;
}

// Helper functions

function getApiUrl() {
  var properties = PropertiesService.getUserProperties();
  return properties.getProperty('ECON_API_URL') || 'http://localhost:8080';
}

function getApiKey() {
  var properties = PropertiesService.getUserProperties();
  return properties.getProperty('ECON_API_KEY');
}

function setApiUrl(url) {
  var properties = PropertiesService.getUserProperties();
  properties.setProperty('ECON_API_URL', url);
}

function setApiKey(key) {
  var properties = PropertiesService.getUserProperties();
  properties.setProperty('ECON_API_KEY', key);
}
