# SPDX-License-Identifier: MPL-2.0
# Multi-stage build for Economic Toolkit REST API server

# Stage 1: Julia base
FROM julia:1.10-slim AS julia-base

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy Julia project files
COPY src/julia/ /app/src/julia/
COPY Project.toml Manifest.toml /app/

# Install Julia dependencies
RUN julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'

# Stage 2: Deno for ReScript/TypeScript
FROM denoland/deno:1.40.0 AS deno-base

WORKDIR /app

# Copy Deno configuration
COPY deno.json /app/
COPY src/rescript/ /app/src/rescript/

# Stage 3: Final runtime image
FROM julia:1.10-slim

WORKDIR /app

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy Julia environment from build stage
COPY --from=julia-base /app /app
COPY --from=deno-base /app /app

# Copy application files
COPY examples/ /app/examples/
COPY scripts/ /app/scripts/
COPY docs/ /app/docs/
COPY README.adoc /app/
COPY VERSION /app/

# Expose API port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Run server
CMD ["julia", "--project=.", "src/julia/EconomicToolkit.jl", "--dev"]
