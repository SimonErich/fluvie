# Fluvie editor and presenter web app.
FROM ghcr.io/cirruslabs/flutter:3.44.0 AS build

WORKDIR /src
COPY . .
RUN flutter pub get

# The in-browser encoder's runtime is deliberately fetched at image-build
# time, not committed. The script pins the package ranges used by the app.
RUN apt-get update \
    && apt-get install -y --no-install-recommends nodejs npm \
    && rm -rf /var/lib/apt/lists/* \
    && bash apps/slides/tool/fetch_ffmpeg.sh

WORKDIR /src/apps/slides
RUN flutter build web --release --no-web-resources-cdn

FROM nginx:alpine
COPY --from=build /src/apps/slides/build/web /usr/share/nginx/html
COPY deploy/nginx/spa.conf /etc/nginx/conf.d/default.conf
# Pre-compress text and wasm assets for gzip_static. Media files are already
# compressed formats and are deliberately excluded.
RUN apk add --no-cache gzip \
    && find /usr/share/nginx/html -type f \
      \( -name '*.html' -o -name '*.js' -o -name '*.css' -o -name '*.json' \
         -o -name '*.wasm' -o -name '*.svg' -o -name '*.xml' -o -name '*.txt' \
         -o -name '*.ttf' -o -name '*.otf' \) \
      -exec gzip -9 -k {} \; \
    && apk del gzip
EXPOSE 80
