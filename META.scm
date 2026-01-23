;;; SPDX-License-Identifier: PMPL-1.0-or-later
;;;
;;; META.scm - Excel Economic Numbers Tool Meta Information

(define-meta excel-economic-numbers-tool
  (architecture-decisions
    (adr-001
      (status accepted)
      (date "2025-12-01")
      (title "Multi-Platform Architecture")
      (decision "Platform-agnostic with Julia backend, REST/GraphQL APIs, platform-specific clients")
      (consequences "Wide adoption, more maintenance, testing complexity")))

  (design-rationale
    (why-open-source "Economic research should be accessible to all")
    (why-multi-platform "Meet users where they are")
    (why-standardization "EDIS reduces fragmentation, enables ecosystem"))

  (technical-philosophy
    (principles
      "Simplicity over cleverness"
      "Explicit over implicit"
      "Performance matters, correctness first")))
