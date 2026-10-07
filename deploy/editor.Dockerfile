# Fluvie editor and presenter web app.
FROM ghcr.io/cirruslabs/flutter:3.44.0 AS build

WORKDIR /src
COPY . .
RUN flutter pub get
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
