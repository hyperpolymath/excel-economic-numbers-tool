# Excel-Economic-Numbers-Tool - ReScript Development Tasks
set shell := ["bash", "-uc"]
set dotenv-load := true

project := "Excel-Economic-Numbers-Tool"

# Show all recipes
default:
    @just --list --unsorted

# Build
build:
    npx rescript build

# Build clean
build-clean:
    npx rescript build -clean-world

# Watch mode
watch:
    npx rescript build -w

# Format code
fmt:
    npx rescript format -all

# Clean
clean:
    npx rescript clean

# Install dependencies
install:
    npm install

# Run tests
test:
    npm test

# All checks before commit
pre-commit: build test
    @echo "All checks passed!"
