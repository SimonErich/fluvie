# Fluvie MCP server (mcp.fluvie.dev), compiled to a native binary.
#
# It does not render on its own: it delegates to a Fluvie render API, so set
# FLUVIE_API_URL (and FLUVIE_API_TOKEN if the API needs one) at runtime. Protect
# the public endpoint with FLUVIE_MCP_TOKEN.
#
#   docker build -f deploy/mcp.Dockerfile -t fluvie-mcp .
#   docker run -p 8080:8080 -e FLUVIE_API_URL=https://api.fluvie.dev fluvie-mcp
#
# The build uses the Flutter image because the pub workspace contains Flutter
# packages (so `flutter pub get` is needed to resolve it), even though fluvie_mcp
# itself is pure Dart.
FROM ghcr.io/cirruslabs/flutter:3.44.0 AS build
WORKDIR /src
COPY . .
RUN flutter pub get
RUN dart compile exe packages/fluvie_mcp/bin/fluvie_mcp.dart -o /server

# A small glibc runtime for the AOT binary.
FROM debian:bookworm-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /server /usr/local/bin/fluvie_mcp
ENV HOST=0.0.0.0 \
    PORT=8080
EXPOSE 8080
ENTRYPOINT ["fluvie_mcp", "--http"]
