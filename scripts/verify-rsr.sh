#!/usr/bin/env bash
#
# RSR Compliance Verification Script
# Checks project against Rhodium Standard Repository Framework
#

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# Print functions
check_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED_CHECKS++))
    ((TOTAL_CHECKS++))
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED_CHECKS++))
    ((TOTAL_CHECKS++))
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((TOTAL_CHECKS++))
}

print_header() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  RSR Compliance Verification - Economic Toolkit v2.0      ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${BLUE}==== $1 ====${NC}"
}

# Check functions
check_file() {
    if [ -f "$1" ]; then
        check_pass "$2"
        return 0
    else
        check_fail "$2 (missing: $1)"
        return 1
    fi
}

check_dir() {
    if [ -d "$1" ]; then
        check_pass "$2"
        return 0
    else
        check_fail "$2 (missing: $1)"
        return 1
    fi
}

# Main verification
print_header

# Category 1: Documentation
print_section "1. Documentation (9 required files)"

check_file "README.md" "README.md present"
check_file "LICENSE" "LICENSE present"
check_file "LICENSE-PALIMPSEST.txt" "LICENSE-PALIMPSEST.txt present (dual license)"
check_file "SECURITY.md" "SECURITY.md present (RFC 9116)"
check_file "CONTRIBUTING.md" "CONTRIBUTING.md present"
check_file "CODE_OF_CONDUCT.md" "CODE_OF_CONDUCT.md present"
check_file "MAINTAINERS.md" "MAINTAINERS.md present"
check_file "CHANGELOG.md" "CHANGELOG.md present"
check_file "TPCF.md" "TPCF.md present (Tri-Perimeter Framework)"

# Category 2: .well-known/ Directory
print_section "2. .well-known/ Directory (RFC 9116)"

check_dir ".well-known" ".well-known/ directory"
check_file ".well-known/security.txt" "security.txt (RFC 9116 compliant)"
check_file ".well-known/ai.txt" "ai.txt (AI training policy)"
check_file ".well-known/humans.txt" "humans.txt (attribution)"

# Category 3: Build System
print_section "3. Build System"

check_file "Justfile" "Justfile (build automation)"
check_file "flake.nix" "flake.nix (Nix reproducible builds)"
check_file ".gitlab-ci.yml" "GitLab CI/CD pipeline"
check_file ".github/workflows/ci.yml" "GitHub Actions workflow"

# Category 4: Project Structure
print_section "4. Project Structure"

check_dir "src" "src/ directory"
check_dir "src/julia" "src/julia/ (backend)"
check_dir "src/typescript" "src/typescript/ (frontend)"
check_dir "tests" "tests/ directory"
check_dir "tests/julia" "tests/julia/"
check_dir "tests/typescript" "tests/typescript/"
check_dir "docs" "docs/ directory"
check_dir "examples" "examples/ directory"

# Category 5: Configuration Files
print_section "5. Configuration Files"

check_file "Project.toml" "Project.toml (Julia dependencies)"
check_file "package.json" "package.json (Node dependencies)"
check_file "tsconfig.json" "tsconfig.json (TypeScript config)"
check_file ".eslintrc.json" ".eslintrc.json (linting)"
check_file ".prettierrc.json" ".prettierrc.json (formatting)"
check_file ".gitignore" ".gitignore"

# Category 6: Source Files
print_section "6. Core Source Files"

check_file "src/julia/EconomicToolkit.jl" "Main Julia module"
check_file "src/julia/cache/sqlite_cache.jl" "SQLite cache (offline-first)"
check_file "src/julia/utils/rate_limiter.jl" "Rate limiter"
check_file "src/julia/utils/retry.jl" "Retry logic"

# Data sources
echo ""
echo -e "${BLUE}Data Source Clients:${NC}"
check_file "src/julia/data_sources/FRED.jl" "FRED client"
check_file "src/julia/data_sources/WorldBank.jl" "World Bank client"
check_file "src/julia/data_sources/IMF.jl" "IMF client"
check_file "src/julia/data_sources/OECD.jl" "OECD client"
check_file "src/julia/data_sources/DBnomics.jl" "DBnomics client"
check_file "src/julia/data_sources/ECB.jl" "ECB client"

# Formulas
echo ""
echo -e "${BLUE}Economic Formulas:${NC}"
check_file "src/julia/formulas/elasticity.jl" "Elasticity calculations"
check_file "src/julia/formulas/gdp_growth.jl" "GDP growth rates"
check_file "src/julia/formulas/lorenz.jl" "Inequality measures"
check_file "src/julia/formulas/constraints.jl" "Constraint system"

# Adapters
echo ""
echo -e "${BLUE}Platform Adapters:${NC}"
check_file "src/typescript/adapters/ISpreadsheetAdapter.ts" "Abstraction interface"
check_file "src/typescript/adapters/OfficeJsAdapter.ts" "Excel adapter"
check_file "src/typescript/adapters/UnoAdapter.js" "LibreOffice adapter"

# Category 7: Tests
print_section "7. Tests"

check_file "tests/julia/runtests.jl" "Julia test runner"
check_file "tests/julia/test_rate_limiter.jl" "Rate limiter tests"
check_file "tests/julia/test_elasticity.jl" "Elasticity tests"
check_file "tests/julia/test_gdp_growth.jl" "GDP growth tests"
check_file "tests/julia/test_lorenz.jl" "Inequality tests"
check_file "tests/julia/test_constraints.jl" "Constraint tests"

# Run tests if requested
if command -v julia &> /dev/null && [ "${RUN_TESTS:-0}" = "1" ]; then
    echo ""
    echo -e "${BLUE}Running Julia Tests...${NC}"
    if julia --project=. tests/julia/runtests.jl > /dev/null 2>&1; then
        check_pass "Julia tests passing"
    else
        check_fail "Julia tests failing"
    fi
fi

# Category 8: Documentation
print_section "8. Extended Documentation"

check_file "docs/architecture.md" "Architecture documentation"
check_file "docs/data_sources.md" "Data sources guide"
check_file "docs/api_reference.md" "API reference"
check_file "docs/developer_guide.md" "Developer guide"

# Category 9: Examples
print_section "9. Examples"

check_file "examples/basic_usage.jl" "Basic usage examples"
check_file "examples/advanced_usage.jl" "Advanced usage examples"

# Category 10: Scripts
print_section "10. Utility Scripts"

check_file "bootstrap.sh" "bootstrap.sh (dependency checker)"
check_file "deploy.sh" "deploy.sh (deployment script)"
check_file "verify-rsr.sh" "verify-rsr.sh (this script)"

if [ -f "bootstrap.sh" ] && [ ! -x "bootstrap.sh" ]; then
    check_warn "bootstrap.sh not executable (run: chmod +x bootstrap.sh)"
fi

if [ -f "deploy.sh" ] && [ ! -x "deploy.sh" ]; then
    check_warn "deploy.sh not executable (run: chmod +x deploy.sh)"
fi

# Category 11: RSR-Specific
print_section "11. RSR Compliance"

check_file "RSR.md" "RSR compliance documentation"

# Check TPCF perimeter declaration
if [ -f "TPCF.md" ]; then
    if grep -q "Perimeter 3" TPCF.md; then
        check_pass "TPCF perimeter declared (Perimeter 3)"
    else
        check_fail "TPCF perimeter not clearly declared"
    fi
fi

# Check for dual licensing
if [ -f "LICENSE" ] && [ -f "LICENSE-PALIMPSEST.txt" ]; then
    check_pass "Dual licensing (MIT OR Palimpsest-0.8)"
else
    check_fail "Dual licensing not complete"
fi

# Category 12: Type Safety
print_section "12. Type Safety"

if grep -q "::.*Type" src/julia/data_sources/FRED.jl 2>/dev/null; then
    check_pass "Julia type annotations present"
else
    check_warn "Julia type annotations sparse"
fi

if [ -f "tsconfig.json" ]; then
    if grep -q "\"strict\": true" tsconfig.json; then
        check_pass "TypeScript strict mode enabled"
    else
        check_fail "TypeScript strict mode disabled"
    fi
fi

# Category 13: Security
print_section "13. Security"

# Check for security.txt expiration
if [ -f ".well-known/security.txt" ]; then
    if grep -q "Expires:" .well-known/security.txt; then
        EXPIRES=$(grep "Expires:" .well-known/security.txt | cut -d' ' -f2)
        check_pass "security.txt has expiration date: $EXPIRES"
    else
        check_fail "security.txt missing Expires field (RFC 9116 violation)"
    fi
fi

# Check for no hardcoded secrets
if grep -r "password\|secret\|key" src/ --include="*.jl" --include="*.ts" | grep -v "api_key::Union" | grep -v "# API key" | grep -v "API Key" > /dev/null 2>&1; then
    check_warn "Potential hardcoded secrets found (review code)"
else
    check_pass "No obvious hardcoded secrets"
fi

# Category 14: Offline-First
print_section "14. Offline-First"

if [ -f "src/julia/cache/sqlite_cache.jl" ]; then
    if grep -q "SQLite" src/julia/cache/sqlite_cache.jl; then
        check_pass "Persistent cache implemented (SQLite)"
    else
        check_fail "Cache implementation unclear"
    fi
fi

if grep -q "with_retry_and_cache" src/julia/utils/retry.jl 2>/dev/null; then
    check_pass "Cache fallback on network failure"
else
    check_warn "Cache fallback not verified"
fi

# Summary
print_section "Summary"

SCORE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))

echo ""
echo "Total Checks:  $TOTAL_CHECKS"
echo -e "${GREEN}Passed:        $PASSED_CHECKS${NC}"
echo -e "${RED}Failed:        $FAILED_CHECKS${NC}"
echo ""
echo -e "RSR Compliance Score: ${BLUE}$SCORE%${NC}"

if [ $SCORE -ge 90 ]; then
    echo -e "RSR Level: ${GREEN}Gold ⭐⭐⭐${NC}"
elif [ $SCORE -ge 75 ]; then
    echo -e "RSR Level: ${BLUE}Silver ⭐⭐${NC}"
elif [ $SCORE -ge 50 ]; then
    echo -e "RSR Level: ${YELLOW}Bronze ⭐${NC}"
else
    echo -e "RSR Level: ${RED}Below Bronze${NC}"
fi

echo ""

if [ $FAILED_CHECKS -eq 0 ]; then
    echo -e "${GREEN}✓ All RSR compliance checks passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some RSR compliance checks failed.${NC}"
    echo "See above for details."
    exit 1
fi
