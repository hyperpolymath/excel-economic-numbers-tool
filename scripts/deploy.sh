#!/usr/bin/env bash
#
# deploy.sh - Deployment script for Economic Toolkit v2.0
#

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Economic Toolkit v2.0 - Deployment${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Check if we're in the right directory
if [ ! -f "Project.toml" ] || [ ! -f "package.json" ]; then
    echo -e "${RED}Error: Must run from project root directory${NC}"
    exit 1
fi

# Function to print section headers
print_section() {
    echo ""
    echo -e "${BLUE}==== $1 ====${NC}"
}

# Check dependencies
print_section "Checking dependencies"
./bootstrap.sh || exit 1

# Clean previous builds
print_section "Cleaning previous builds"
just clean || true

# Install dependencies
print_section "Installing dependencies"
just install

# Run tests
print_section "Running tests"
just test

# Build everything
print_section "Building project"
just build

# Build container image
print_section "Building container image"
if command -v podman &> /dev/null; then
    podman build -t economic-toolkit:latest -f Containerfile .
    echo -e "${GREEN}✓ Container image built${NC}"
else
    echo -e "${RED}⚠ Podman not found, skipping container build${NC}"
fi

# Package Excel add-in
print_section "Packaging Excel add-in"
if [ -f "dist/officejs/manifest.xml" ]; then
    echo -e "${GREEN}✓ Excel add-in ready: dist/officejs/${NC}"
else
    echo -e "${RED}✗ Excel add-in build failed${NC}"
    exit 1
fi

# Package LibreOffice extension
print_section "Packaging LibreOffice extension"
if [ -f "dist/uno/economic-toolkit.oxt" ]; then
    echo -e "${GREEN}✓ LibreOffice extension ready: dist/uno/economic-toolkit.oxt${NC}"
else
    echo -e "${RED}✗ LibreOffice extension build failed${NC}"
    exit 1
fi

print_section "Deployment Complete"
echo ""
echo "Artifacts:"
echo "  - Excel add-in:         dist/officejs/manifest.xml"
echo "  - LibreOffice extension: dist/uno/economic-toolkit.oxt"
echo "  - Container image:       economic-toolkit:latest"
echo ""
echo -e "${GREEN}✓ Deployment successful!${NC}"
