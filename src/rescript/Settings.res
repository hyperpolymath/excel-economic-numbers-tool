/**
 * Settings Task Pane
 *
 * Provides user-configurable settings for the Economic Toolkit including:
 * - API keys for data sources
 * - Cache settings (TTL, location, size limits)
 * - Rate limiting preferences
 * - Retry logic configuration
 * - Display preferences
 */

// Types
type apiKey = {
  source: string,
  key: option<string>,
  isRequired: bool,
  helpUrl: string,
}

type cacheSettings = {
  enabled: bool,
  ttlHours: int,
  maxSizeMb: int,
  location: string,
}

type rateLimitSettings = {
  enabled: bool,
  customLimits: Map.t<string, int>, // source -> requests per minute
}

type retrySettings = {
  enabled: bool,
  maxRetries: int,
  initialDelayMs: int,
  useExponentialBackoff: bool,
}

type displaySettings = {
  showNotifications: bool,
  autoRefresh: bool,
  refreshIntervalMinutes: int,
  dateFormat: string,
  numberFormat: string,
}

type state = {
  apiKeys: array<apiKey>,
  cache: cacheSettings,
  rateLimit: rateLimitSettings,
  retry: retrySettings,
  display: displaySettings,
  hasChanges: bool,
  isSaving: bool,
  saveMessage: option<string>,
}

type action =
  | UpdateApiKey(string, string)
  | UpdateCacheEnabled(bool)
  | UpdateCacheTtl(int)
  | UpdateCacheSize(int)
  | UpdateRateLimitEnabled(bool)
  | UpdateCustomLimit(string, int)
  | UpdateRetryEnabled(bool)
  | UpdateMaxRetries(int)
  | UpdateRetryDelay(int)
  | UpdateRetryBackoff(bool)
  | UpdateDisplayNotifications(bool)
  | UpdateAutoRefresh(bool)
  | UpdateRefreshInterval(int)
  | UpdateDateFormat(string)
  | UpdateNumberFormat(string)
  | SaveSettings
  | SaveComplete(string)
  | SaveFailed(string)
  | ResetToDefaults

// Default settings
let defaultApiKeys: array<apiKey> = [
  {
    source: "FRED",
    key: None,
    isRequired: false,
    helpUrl: "https://fred.stlouisfed.org/docs/api/api_key.html",
  },
  {
    source: "World Bank",
    key: None,
    isRequired: false,
    helpUrl: "https://datahelpdesk.worldbank.org/knowledgebase/articles/889392",
  },
  {
    source: "IMF",
    key: None,
    isRequired: false,
    helpUrl: "https://datahelp.imf.org/knowledgebase/articles/667681",
  },
  {
    source: "OECD",
    key: None,
    isRequired: false,
    helpUrl: "https://data.oecd.org/api/",
  },
  {
    source: "DBnomics",
    key: None,
    isRequired: false,
    helpUrl: "https://api.db.nomics.world/",
  },
  {
    source: "ECB",
    key: None,
    isRequired: false,
    helpUrl: "https://data.ecb.europa.eu/",
  },
]

let defaultCacheSettings: cacheSettings = {
  enabled: true,
  ttlHours: 24,
  maxSizeMb: 100,
  location: "~/.economic-toolkit/cache",
}

let defaultRateLimitSettings: rateLimitSettings = {
  enabled: true,
  customLimits: Map.make(),
}

let defaultRetrySettings: retrySettings = {
  enabled: true,
  maxRetries: 3,
  initialDelayMs: 2000,
  useExponentialBackoff: true,
}

let defaultDisplaySettings: displaySettings = {
  showNotifications: true,
  autoRefresh: false,
  refreshIntervalMinutes: 60,
  dateFormat: "YYYY-MM-DD",
  numberFormat: "#,##0.00",
}

// Reducer
let reducer = (state: state, action: action): state => {
  switch action {
  | UpdateApiKey(source, key) => {
      ...state,
      apiKeys: Belt.Array.map(state.apiKeys, ak =>
        ak.source === source ? {...ak, key: Some(key)} : ak
      ),
      hasChanges: true,
    }
  | UpdateCacheEnabled(enabled) => {
      ...state,
      cache: {...state.cache, enabled: enabled},
      hasChanges: true,
    }
  | UpdateCacheTtl(hours) => {
      ...state,
      cache: {...state.cache, ttlHours: hours},
      hasChanges: true,
    }
  | UpdateCacheSize(mb) => {
      ...state,
      cache: {...state.cache, maxSizeMb: mb},
      hasChanges: true,
    }
  | UpdateRateLimitEnabled(enabled) => {
      ...state,
      rateLimit: {...state.rateLimit, enabled: enabled},
      hasChanges: true,
    }
  | UpdateCustomLimit(source, limit) => {
      ...state,
      rateLimit: {
        ...state.rateLimit,
        customLimits: Map.set(state.rateLimit.customLimits, source, limit),
      },
      hasChanges: true,
    }
  | UpdateRetryEnabled(enabled) => {
      ...state,
      retry: {...state.retry, enabled: enabled},
      hasChanges: true,
    }
  | UpdateMaxRetries(max) => {
      ...state,
      retry: {...state.retry, maxRetries: max},
      hasChanges: true,
    }
  | UpdateRetryDelay(ms) => {
      ...state,
      retry: {...state.retry, initialDelayMs: ms},
      hasChanges: true,
    }
  | UpdateRetryBackoff(enabled) => {
      ...state,
      retry: {...state.retry, useExponentialBackoff: enabled},
      hasChanges: true,
    }
  | UpdateDisplayNotifications(enabled) => {
      ...state,
      display: {...state.display, showNotifications: enabled},
      hasChanges: true,
    }
  | UpdateAutoRefresh(enabled) => {
      ...state,
      display: {...state.display, autoRefresh: enabled},
      hasChanges: true,
    }
  | UpdateRefreshInterval(minutes) => {
      ...state,
      display: {...state.display, refreshIntervalMinutes: minutes},
      hasChanges: true,
    }
  | UpdateDateFormat(format) => {
      ...state,
      display: {...state.display, dateFormat: format},
      hasChanges: true,
    }
  | UpdateNumberFormat(format) => {
      ...state,
      display: {...state.display, numberFormat: format},
      hasChanges: true,
    }
  | SaveSettings => {...state, isSaving: true}
  | SaveComplete(msg) => {
      ...state,
      isSaving: false,
      hasChanges: false,
      saveMessage: Some(msg),
    }
  | SaveFailed(msg) => {
      ...state,
      isSaving: false,
      saveMessage: Some("Error: " ++ msg),
    }
  | ResetToDefaults => {
      apiKeys: defaultApiKeys,
      cache: defaultCacheSettings,
      rateLimit: defaultRateLimitSettings,
      retry: defaultRetrySettings,
      display: defaultDisplaySettings,
      hasChanges: true,
      isSaving: false,
      saveMessage: Some("Settings reset to defaults"),
    }
  }
}

// Initial state
let initialState: state = {
  apiKeys: defaultApiKeys,
  cache: defaultCacheSettings,
  rateLimit: defaultRateLimitSettings,
  retry: defaultRetrySettings,
  display: defaultDisplaySettings,
  hasChanges: false,
  isSaving: false,
  saveMessage: None,
}

// API calls
let saveSettings = async (state: state) => {
  let url = "http://localhost:8080/api/v1/settings"

  let payload = {
    "apiKeys": Belt.Array.map(state.apiKeys, ak => {
      "source": ak.source,
      "key": ak.key,
    }),
    "cache": {
      "enabled": state.cache.enabled,
      "ttlHours": state.cache.ttlHours,
      "maxSizeMb": state.cache.maxSizeMb,
    },
    "rateLimit": {
      "enabled": state.rateLimit.enabled,
      "customLimits": Belt.Map.toArray(state.rateLimit.customLimits),
    },
    "retry": {
      "enabled": state.retry.enabled,
      "maxRetries": state.retry.maxRetries,
      "initialDelayMs": state.retry.initialDelayMs,
      "useExponentialBackoff": state.retry.useExponentialBackoff,
    },
    "display": {
      "showNotifications": state.display.showNotifications,
      "autoRefresh": state.display.autoRefresh,
      "refreshIntervalMinutes": state.display.refreshIntervalMinutes,
      "dateFormat": state.display.dateFormat,
      "numberFormat": state.display.numberFormat,
    },
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
    Ok("Settings saved successfully")
  } else {
    Error("Failed to save settings: " ++ response.statusText)
  }
}

// Components
module ApiKeysSection = {
  @react.component
  let make = (~apiKeys: array<apiKey>, ~onChange) => {
    <div className="settings-section">
      <h3> {React.string("API Keys")} </h3>
      <p className="help-text">
        {React.string("Most data sources don't require API keys, but providing one may increase rate limits.")}
      </p>
      {Belt.Array.map(apiKeys, ak =>
        <div key={ak.source} className="api-key-item">
          <label>
            <strong> {React.string(ak.source)} </strong>
            {ak.isRequired
              ? <span className="required"> {React.string(" (required)")} </span>
              : React.null}
          </label>
          <input
            type_="password"
            value={ak.key->Belt.Option.getWithDefault("")}
            onChange={e => onChange(ak.source, ReactEvent.Form.target(e)["value"])}
            placeholder="Enter API key (optional)"
          />
          <a href={ak.helpUrl} target="_blank" className="help-link">
            {React.string("Get API key")}
          </a>
        </div>
      )->React.array}
    </div>
  }
}

module CacheSection = {
  @react.component
  let make = (~cache: cacheSettings, ~onEnabledChange, ~onTtlChange, ~onSizeChange) => {
    <div className="settings-section">
      <h3> {React.string("Cache Settings")} </h3>
      <div className="checkbox-item">
        <input
          type_="checkbox"
          checked={cache.enabled}
          onChange={e => onEnabledChange(ReactEvent.Form.target(e)["checked"])}
        />
        <label> {React.string("Enable caching (recommended)")} </label>
      </div>
      <div className="form-group">
        <label> {React.string("Cache TTL (hours)")} </label>
        <input
          type_="number"
          value={Belt.Int.toString(cache.ttlHours)}
          onChange={e =>
            onTtlChange(ReactEvent.Form.target(e)["value"]->Belt.Int.fromString->Belt.Option.getWithDefault(24))}
          min="1"
          max="720"
        />
      </div>
      <div className="form-group">
        <label> {React.string("Max cache size (MB)")} </label>
        <input
          type_="number"
          value={Belt.Int.toString(cache.maxSizeMb)}
          onChange={e =>
            onSizeChange(ReactEvent.Form.target(e)["value"]->Belt.Int.fromString->Belt.Option.getWithDefault(100))}
          min="10"
          max="1000"
        />
      </div>
      <p className="info-text">
        {React.string("Cache location: " ++ cache.location)}
      </p>
    </div>
  }
}

module RetrySection = {
  @react.component
  let make = (~retry: retrySettings, ~onEnabledChange, ~onMaxRetriesChange, ~onDelayChange, ~onBackoffChange) => {
    <div className="settings-section">
      <h3> {React.string("Retry Settings")} </h3>
      <div className="checkbox-item">
        <input
          type_="checkbox"
          checked={retry.enabled}
          onChange={e => onEnabledChange(ReactEvent.Form.target(e)["checked"])}
        />
        <label> {React.string("Enable automatic retries")} </label>
      </div>
      <div className="form-group">
        <label> {React.string("Max retries")} </label>
        <input
          type_="number"
          value={Belt.Int.toString(retry.maxRetries)}
          onChange={e =>
            onMaxRetriesChange(ReactEvent.Form.target(e)["value"]->Belt.Int.fromString->Belt.Option.getWithDefault(3))}
          min="1"
          max="10"
        />
      </div>
      <div className="form-group">
        <label> {React.string("Initial delay (ms)")} </label>
        <input
          type_="number"
          value={Belt.Int.toString(retry.initialDelayMs)}
          onChange={e =>
            onDelayChange(ReactEvent.Form.target(e)["value"]->Belt.Int.fromString->Belt.Option.getWithDefault(2000))}
          min="100"
          max="10000"
          step="100"
        />
      </div>
      <div className="checkbox-item">
        <input
          type_="checkbox"
          checked={retry.useExponentialBackoff}
          onChange={e => onBackoffChange(ReactEvent.Form.target(e)["checked"])}
        />
        <label> {React.string("Use exponential backoff")} </label>
      </div>
    </div>
  }
}

module DisplaySection = {
  @react.component
  let make = (~display: displaySettings, ~onNotificationsChange, ~onAutoRefreshChange, ~onIntervalChange) => {
    <div className="settings-section">
      <h3> {React.string("Display Settings")} </h3>
      <div className="checkbox-item">
        <input
          type_="checkbox"
          checked={display.showNotifications}
          onChange={e => onNotificationsChange(ReactEvent.Form.target(e)["checked"])}
        />
        <label> {React.string("Show notifications")} </label>
      </div>
      <div className="checkbox-item">
        <input
          type_="checkbox"
          checked={display.autoRefresh}
          onChange={e => onAutoRefreshChange(ReactEvent.Form.target(e)["checked"])}
        />
        <label> {React.string("Auto-refresh data")} </label>
      </div>
      {display.autoRefresh
        ? <div className="form-group">
            <label> {React.string("Refresh interval (minutes)")} </label>
            <input
              type_="number"
              value={Belt.Int.toString(display.refreshIntervalMinutes)}
              onChange={e =>
                onIntervalChange(
                  ReactEvent.Form.target(e)["value"]->Belt.Int.fromString->Belt.Option.getWithDefault(60),
                )}
              min="5"
              max="1440"
            />
          </div>
        : React.null}
    </div>
  }
}

// Main component
@react.component
let make = () => {
  let (state, dispatch) = React.useReducer(reducer, initialState)

  let handleSave = async () => {
    dispatch(SaveSettings)
    let result = await saveSettings(state)
    switch result {
    | Ok(msg) => dispatch(SaveComplete(msg))
    | Error(msg) => dispatch(SaveFailed(msg))
    }
  }

  <div className="settings-panel">
    <div className="header">
      <h2> {React.string("Settings")} </h2>
    </div>

    <ApiKeysSection
      apiKeys={state.apiKeys}
      onChange={(source, key) => dispatch(UpdateApiKey(source, key))}
    />

    <CacheSection
      cache={state.cache}
      onEnabledChange={enabled => dispatch(UpdateCacheEnabled(enabled))}
      onTtlChange={hours => dispatch(UpdateCacheTtl(hours))}
      onSizeChange={mb => dispatch(UpdateCacheSize(mb))}
    />

    <RetrySection
      retry={state.retry}
      onEnabledChange={enabled => dispatch(UpdateRetryEnabled(enabled))}
      onMaxRetriesChange={max => dispatch(UpdateMaxRetries(max))}
      onDelayChange={ms => dispatch(UpdateRetryDelay(ms))}
      onBackoffChange={enabled => dispatch(UpdateRetryBackoff(enabled))}
    />

    <DisplaySection
      display={state.display}
      onNotificationsChange={enabled => dispatch(UpdateDisplayNotifications(enabled))}
      onAutoRefreshChange={enabled => dispatch(UpdateAutoRefresh(enabled))}
      onIntervalChange={minutes => dispatch(UpdateRefreshInterval(minutes))}
    />

    {state.saveMessage->Belt.Option.isSome
      ? <div className="save-message">
          {React.string(state.saveMessage->Belt.Option.getWithDefault(""))}
        </div>
      : React.null}

    <div className="actions">
      <button
        onClick={_ => handleSave()->ignore}
        disabled={!state.hasChanges || state.isSaving}
        className="btn-primary">
        {React.string(state.isSaving ? "Saving..." : "Save Settings")}
      </button>
      <button
        onClick={_ => dispatch(ResetToDefaults)}
        className="btn-secondary">
        {React.string("Reset to Defaults")}
      </button>
    </div>
  </div>
}
