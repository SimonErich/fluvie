# Fluvie live demo (demo.fluvie.dev): the example app, built for the web and
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

WORKDIR /src
COPY . .

# Resolve the workspace once at the root, then build the example for the web.
RUN flutter pub get
WORKDIR /src/example
RUN flutter build web --release \
      --no-web-resources-cdn \
      --dart-define=FLUVIE_API_URL=${FLUVIE_API_URL} \
      --dart-define=FLUVIE_API_TOKEN=${FLUVIE_API_TOKEN}

FROM nginx:alpine
COPY --from=build /src/example/build/web /usr/share/nginx/html
COPY deploy/nginx/spa.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
