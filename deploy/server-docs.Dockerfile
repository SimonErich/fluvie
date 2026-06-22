# Fluvie server image (slim, docs/MCP only).
#
# A tiny pure-Dart AOT build for the documentation helper and the MCP server with
# NO render toolchain (no Flutter SDK, no ffmpeg). It bundles the documentation
# corpus and the VideoSpec schema, so the docs tools and get_video_spec_schema work
# offline. The render API is disabled here (FLUVIE_ENABLE_API=false). To also render
# from this slim endpoint, set FLUVIE_API_URL to a full Fluvie server and the MCP
# build-mode tools will forward there.
#
#   docker build -f deploy/server-docs.Dockerfile -t fluvie-server-docs .
#   docker run -p 8080:8080 fluvie-server-docs
#
# The build uses the Flutter image because the pub workspace contains Flutter
# packages (so `flutter pub get` is needed to resolve it), even though the server
# binary itself is pure Dart.
FROM ghcr.io/cirruslabs/flutter:3.44.0 AS build
WORKDIR /src
COPY . .
RUN flutter pub get
RUN dart compile exe packages/fluvie_server/bin/fluvie_server.dart -o /server

# A small glibc runtime for the AOT binary.
FROM debian:bookworm-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /server /usr/local/bin/fluvie_server
COPY documentation /app/documentation
COPY packages/fluvie_server/assets/video_spec_schema.json /app/schema/video_spec_schema.json
ENV HOST=0.0.0.0 \
    PORT=8080 \
    FLUVIE_ENABLE_API=false \
    FLUVIE_DOCS_DIR=/app/documentation \
    VIDEO_SPEC_SCHEMA_PATH=/app/schema/video_spec_schema.json
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s \
  CMD curl -fsS "http://localhost:${PORT}/healthz" || exit 1
ENTRYPOINT ["fluvie_server"]
