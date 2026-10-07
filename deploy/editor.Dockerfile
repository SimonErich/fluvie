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
EXPOSE 80
