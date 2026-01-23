#!/usr/bin/env bash
#
# bootstrap.sh - Dependency checker for Economic Toolkit v2.0
# Checks for required dependencies and versions
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track overall status
ALL_CHECKS_PASSED=true

# Print functions
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
    ALL_CHECKS_PASSED=false
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "  $1"
}

# Version comparison function
version_ge() {
    # Compare versions: $1 >= $2
    printf '%s\n%s' "$2" "$1" | sort -V -C
}

echo "========================================="
echo "Economic Toolkit v2.0 - Dependency Check"
echo "========================================="
echo ""

# Check Julia
echo "Checking Julia..."
if command -v julia &> /dev/null; then
    JULIA_VERSION=$(julia --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    if version_ge "$JULIA_VERSION" "1.10.0"; then
        print_success "Julia $JULIA_VERSION (requires ≥1.10.0)"
    else
        print_error "Julia $JULIA_VERSION found, but ≥1.10.0 required"
        print_info "Download from: https://julialang.org/downloads/"
    fi
else
    print_error "Julia not found"
    print_info "Download from: https://julialang.org/downloads/"
fi
echo ""

# Check Node.js
echo "Checking Node.js..."
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    if version_ge "$NODE_VERSION" "20.0.0"; then
        print_success "Node.js v$NODE_VERSION (requires ≥20.0.0)"
    else
        print_error "Node.js v$NODE_VERSION found, but ≥20.0.0 required"
        print_info "Download from: https://nodejs.org/"
    fi
else
    print_error "Node.js not found"
    print_info "Download from: https://nodejs.org/"
fi
echo ""

# Check npm
echo "Checking npm..."
if command -v npm &> /dev/null; then
    NPM_VERSION=$(npm --version)
    print_success "npm v$NPM_VERSION"
else
    print_error "npm not found (usually comes with Node.js)"
fi
echo ""

# Check Podman (optional for containerization)
echo "Checking Podman (optional)..."
if command -v podman &> /dev/null; then
    PODMAN_VERSION=$(podman --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    if version_ge "$PODMAN_VERSION" "4.0.0"; then
        print_success "Podman v$PODMAN_VERSION (requires ≥4.0.0)"
    else
        print_warning "Podman v$PODMAN_VERSION found, but ≥4.0.0 recommended"
        print_info "Download from: https://podman.io/getting-started/installation"
    fi
else
    print_warning "Podman not found (optional, for containerized deployment)"
    print_info "Download from: https://podman.io/getting-started/installation"
fi
echo ""

# Check Git
echo "Checking Git..."
if command -v git &> /dev/null; then
    GIT_VERSION=$(git --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    if version_ge "$GIT_VERSION" "2.30.0"; then
        print_success "Git v$GIT_VERSION (requires ≥2.30.0)"
    else
        print_warning "Git v$GIT_VERSION found, but ≥2.30.0 recommended"
    fi
else
    print_error "Git not found"
    print_info "Download from: https://git-scm.com/downloads"
fi
echo ""

# Check Just (optional build tool)
echo "Checking Just (optional)..."
if command -v just &> /dev/null; then
    JUST_VERSION=$(just --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    if version_ge "$JUST_VERSION" "1.0.0"; then
        print_success "Just v$JUST_VERSION (requires ≥1.0.0)"
    else
        print_warning "Just v$JUST_VERSION found, but ≥1.0.0 recommended"
    fi
else
    print_warning "Just not found (optional, but recommended for development)"
    print_info "Install: cargo install just"
    print_info "Or download from: https://github.com/casey/just"
fi
echo ""

# Check for recommended tools
echo "Checking recommended tools..."

# SQLite3
if command -v sqlite3 &> /dev/null; then
    SQLITE_VERSION=$(sqlite3 --version | awk '{print $1}')
    print_success "SQLite v$SQLITE_VERSION (recommended for cache inspection)"
else
    print_warning "SQLite3 not found (recommended for cache inspection)"
fi

# curl
if command -v curl &> /dev/null; then
    print_success "curl found (used for API testing)"
else
    print_warning "curl not found (recommended for API testing)"
fi

# jq
if command -v jq &> /dev/null; then
    print_success "jq found (useful for JSON processing)"
else
    print_warning "jq not found (recommended for JSON processing)"
fi

echo ""
echo "========================================="

# Final summary
if [ "$ALL_CHECKS_PASSED" = true ]; then
    echo -e "${GREEN}✓ All required dependencies are installed!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Install Julia dependencies:   julia --project=. -e 'using Pkg; Pkg.instantiate()'"
    echo "  2. Install Node dependencies:    npm install"
    echo "  3. Run tests:                    just test   (or npm test)"
    echo "  4. Build project:                just build  (or npm run build)"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some required dependencies are missing or outdated.${NC}"
    echo "Please install the missing dependencies and try again."
    echo ""
    exit 1
fi
