# Containerfile for Economic Toolkit v2.0
# Multi-stage build for efficient image

# Stage 1: Julia build
FROM julia:1.10 AS julia-build

WORKDIR /app

# Copy Julia project files
COPY Project.toml ./
COPY src/julia ./src/julia

# Install Julia dependencies
RUN julia --project=. -e 'using Pkg; Pkg.instantiate()'

# Precompile
RUN julia --project=. -e 'using Pkg; Pkg.precompile()'

# Stage 2: Node build
FROM node:20 AS node-build

WORKDIR /app

# Copy package files
COPY package.json package-lock.json ./

# Install dependencies
RUN npm ci

# Copy source
COPY src/typescript ./src/typescript
COPY tsconfig.json webpack.config.js ./

# Build
RUN npm run build

# Stage 3: Runtime
FROM julia:1.10-slim

WORKDIR /app

# Install Node.js runtime
RUN apt-get update && \
    apt-get install -y curl && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy Julia files from build stage
COPY --from=julia-build /app ./

# Copy Node build from build stage
COPY --from=node-build /app/dist ./dist

# Create cache directory
RUN mkdir -p /root/.economic-toolkit/cache

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Run server
CMD ["julia", "--project=.", "src/julia/EconomicToolkit.jl"]
