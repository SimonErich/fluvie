# Fluvie live demo (demo.fluvie.dev): the gallery example app, built for the web and
# served as static files behind nginx. It renders through a Fluvie render API,
# so point it at one at build time:
#
#   docker build -f deploy/demo.Dockerfile \
#     --build-arg FLUVIE_API_URL=https://api.fluvie.dev \
#     -t fluvie-demo .
#
# CanvasKit is bundled (--no-web-resources-cdn) so the demo has no external CDN
# dependency.
FROM ghcr.io/cirruslabs/flutter:3.44.0 AS build

# Baked in at build time (Flutter web has no runtime env). The token is optional;
# leave it empty for an open render API.
ARG FLUVIE_API_URL=https://api.fluvie.dev
ARG FLUVIE_API_TOKEN=

# ffmpeg pre-renders the default lesson videos baked into the demo (below).
RUN apt-get update \
      && apt-get install -y --no-install-recommends ffmpeg \
      && rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY . .

# Resolve the workspace once at the root.
RUN flutter pub get

# Pre-render the lesson videos into examples/gallery/web/media so `flutter build web`
# bundles them and the demo serves them statically at /media/<key>.mp4 — the
# demo never asks the render API for a default video on page load. The frame
# cache is cleared per render to bound the build's temp usage (each lesson is a
# distinct render, so the cache would only grow).
RUN mkdir -p examples/gallery/web/media \
      && for key in 01_hello_video 02_text_and_motion 03_timing_and_triggers \
           04_scenes_and_transitions 05_images_and_clips 06_collage 07_charts \
           08_code_doc_intro 09_diagrams_and_webviews 10_audio_and_captions \
           11_templates_and_aspects 12_the_kitchen_sink; do \
           dart run packages/fluvie_cli/bin/fluvie.dart render "$key" \
             --out "examples/gallery/web/media/$key.mp4" \
             && rm -rf /tmp/fluvie_frame_cache || exit 1; \
         done

WORKDIR /src/example
RUN flutter build web --release \
      --no-web-resources-cdn \
      --dart-define=FLUVIE_API_URL=${FLUVIE_API_URL} \
      --dart-define=FLUVIE_API_TOKEN=${FLUVIE_API_TOKEN}

FROM nginx:alpine
COPY --from=build /src/examples/gallery/build/web /usr/share/nginx/html
COPY deploy/nginx/spa.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
