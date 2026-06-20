# Fluvie marketing landing (fluvie.dev): a single static page behind nginx.
#
# Build from the repo root so the logo is in the build context:
#   docker build -f deploy/landing.Dockerfile -t fluvie-web .
FROM nginx:alpine
COPY web/landing/index.html /usr/share/nginx/html/index.html
COPY documentation/fluvie_logo.svg /usr/share/nginx/html/fluvie_logo.svg
EXPOSE 80
