# Fluvie render API image.
#
# Rendering is a two-process pipeline: capture frames with `flutter test`
# (headless software rendering — no display server needed) then encode with
# ffmpeg. So the runtime image carries the Flutter SDK, ffmpeg, real fonts, and
# the workspace (the example app is the default RENDER_PROJECT). The server is a
# `dart compile exe` binary that drives that pipeline over HTTP.
FROM debian:bookworm-slim

ENV FLUTTER_VERSION=3.44.0 \
    FLUTTER_HOME=/opt/flutter \
    PATH=/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:/root/.pub-cache/bin:$PATH \
    PUB_CACHE=/root/.pub-cache

# ffmpeg (>= 6.0 on bookworm) for encoding; real fonts so captured text is not
# tofu (CI inherits the runner's fonts; a slim image has none); git/curl/unzip
# for the Flutter SDK.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git unzip xz-utils \
      ffmpeg \
      fontconfig fonts-dejavu fonts-noto-core fonts-noto-color-emoji \
    && rm -rf /var/lib/apt/lists/* \
    && fc-cache -f

# Pin the Flutter SDK to the workspace version and precache the Linux engine.
RUN git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$FLUTTER_HOME" \
    && git config --global --add safe.directory "$FLUTTER_HOME" \
    && flutter config --no-analytics --no-cli-animations \
    && flutter precache --linux \
    && dart pub global activate melos

WORKDIR /app
COPY . .

# Resolve the workspace, then warm the capture harness with one throwaway render
# so the first real request does not pay the kernel-snapshot cost.
RUN melos bootstrap \
    && (dart run packages/fluvie_cli/bin/fluvie.dart render demo --out /tmp/warm.mp4 || true) \
    && rm -f /tmp/warm.mp4 \
    && dart compile exe packages/fluvie_api/bin/fluvie_api.dart -o /usr/local/bin/fluvie_api

ENV HOST=0.0.0.0 \
    PORT=8080 \
    RENDER_PROJECT=/app/example \
    LOCAL_STORAGE_DIR=/data/renders \
    VIDEO_SPEC_SCHEMA_PATH=/app/packages/fluvie_api/assets/video_spec_schema.json

VOLUME ["/data/renders"]
EXPOSE 8080

# A healthcheck against the open liveness endpoint.
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s \
  CMD curl -fsS "http://localhost:${PORT}/v1/healthz" || exit 1

CMD ["fluvie_api"]
