; SPDX-License-Identifier: MPL-2.0
;; guix.scm — GNU Guix package definition for excel-economic-numbers-tool
;; Usage: guix shell -f guix.scm

(use-modules (guix packages)
             (guix build-system gnu)
             (guix licenses))

(package
  (name "excel-economic-numbers-tool")
  (version "0.1.0")
  (source #f)
  (build-system gnu-build-system)
  (synopsis "excel-economic-numbers-tool")
  (description "excel-economic-numbers-tool — part of the hyperpolymath ecosystem.")
  (home-page "https://github.com/hyperpolymath/excel-economic-numbers-tool")
  (license ((@@ (guix licenses) license) "MPL-2.0"
             "https://github.com/hyperpolymath/palimpsest-license")))
