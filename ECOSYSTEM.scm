;;; SPDX-License-Identifier: PMPL-1.0-or-later
;;;
;;; ECOSYSTEM.scm - Excel Economic Numbers Tool Ecosystem Position

(ecosystem
  (version "1.0")
  (name "Excel Economic Numbers Tool")
  (type "economic-data-platform")
  (purpose "Multi-platform economic data access and analysis")

  (related-projects
    (sibling-standard
      (name "FRED API")
      (relationship "Data source provider")
      (url "https://fred.stlouisfed.org/docs/api/"))

    (sibling-standard
      (name "World Bank API")
      (relationship "Data source provider")
      (url "https://datahelpdesk.worldbank.org/")))

  (what-this-is
    "Multi-platform toolkit for economic data access and analysis"
    "Integration layer for 10+ major economic data sources"
    "Real-time collaboration platform for teams"
    "Community-governed open source project")

  (what-this-is-not
    "Not a financial trading platform"
    "Not a premium data provider"
    "Not a statistical analysis software"
    "Not closed-source commercial software"))
