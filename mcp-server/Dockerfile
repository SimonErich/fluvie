# Fluvie MCP Server Dockerfile
# Multi-stage build for minimal production image

# Stage 1: Build
FROM dart:stable AS build

WORKDIR /app

# Copy pubspec files
COPY pubspec.yaml pubspec.lock* ./

# Get dependencies
RUN dart pub get

# Copy source code
COPY . .

# Build AOT compiled executable
RUN dart compile exe bin/server.dart -o bin/server

# Stage 2: Production
FROM debian:bookworm-slim AS production

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -r -s /bin/false fluvie

WORKDIR /app

# Copy compiled binary
COPY --from=build /app/bin/server /app/bin/server

# Copy documentation files (will be mounted in production)
# These are optional - can be overridden with volume mount
COPY --from=build /app/data/docs /app/data/docs

# Set ownership
RUN chown -R fluvie:fluvie /app

# Switch to non-root user
USER fluvie

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Environment variables with defaults
ENV PORT=8080
ENV HOST=0.0.0.0
ENV DOCS_PATH=/app/data/docs
ENV LOG_LEVEL=info

# Run the server
ENTRYPOINT ["/app/bin/server"]
