# Fluvie example web apps, built for the web and served behind nginx:
#   /         the in-browser meme maker (web_browser_studio, ffmpeg.wasm, no backend)
#   /server/  the server-render promo studio (web_server_studio, calls a render API)
#
#   docker build -f deploy/examples.Dockerfile \
#     --build-arg FLUVIE_API_URL=https://api.fluvie.dev -t fluvie-examples .
#
# The in-browser app is served at the site root so its absolute /ffmpeg/ asset
# URLs resolve; the server app is mounted under /server/ with its own base-href.
FROM ghcr.io/cirruslabs/flutter:3.44.0 AS build

# Baked in at build time (Flutter web has no runtime env). Point the server-
# render studio at a running Fluvie render API.
ARG FLUVIE_API_URL=https://api.fluvie.dev

WORKDIR /src
COPY . .

# Resolve the workspace once at the root.
RUN flutter pub get

# Vendor ffmpeg.wasm for the in-browser app, then build it at the site root.
RUN bash examples/web_browser_studio/tool/fetch_ffmpeg.sh
WORKDIR /src/examples/web_browser_studio
RUN flutter build web --release --no-web-resources-cdn

# The server-render studio under /server/, pointed at the render API.
WORKDIR /src/examples/web_server_studio
RUN flutter build web --release --no-web-resources-cdn \
      --base-href=/server/ \
      --dart-define=FLUVIE_API_URL=${FLUVIE_API_URL}

FROM nginx:alpine
COPY --from=build /src/examples/web_browser_studio/build/web /usr/share/nginx/html
COPY --from=build /src/examples/web_server_studio/build/web /usr/share/nginx/html/server
COPY deploy/nginx/examples.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
