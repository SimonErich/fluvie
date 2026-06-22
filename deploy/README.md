# Deploying Fluvie

Everything needed to run the Fluvie services as containers lives here. The
documentation site (docs.fluvie.dev) is hosted on GitHub Pages, not from this
folder.

## Services

| Service | Dockerfile | Env file | Container port | Domain |
| --- | --- | --- | --- | --- |
| `fluvie-server` | `server.Dockerfile` | `env/server.env` | 8080 | api.fluvie.dev |
| `fluvie-server-docs` | `server-docs.Dockerfile` | `env/server-docs.env` | 8080 | mcp.fluvie.dev |
| `fluvie-demo` | `demo.Dockerfile` | `env/demo.env` (build-time) | 80 | demo.fluvie.dev |

`fluvie-server` is the full server: the render API, the MCP server, and the
documentation helper in one binary, each toggled by env (`FLUVIE_ENABLE_API` /
`_MCP` / `_DOCS`). It carries the Flutter SDK and ffmpeg, so it can render.

`fluvie-server-docs` is a slim, pure-Dart build of the same binary with no render
toolchain: the documentation helper and the MCP docs tools, offline. Point it at a
full server with `FLUVIE_API_URL` to render through it. Run just one of the two —
the slim image only when you want a tiny docs/MCP endpoint separate from rendering.

All build contexts are the repo root; the Dockerfiles just live under `deploy/`.
The marketing landing (fluvie.dev) is not a container here; it is built from
`web/site` and served by GitHub Pages (see `.github/workflows/website.yml`).

## Env files

Each service has its own documented template under `env/`. Copy and edit:

```sh
cp deploy/env/server.env.example      deploy/env/server.env
cp deploy/env/server-docs.env.example deploy/env/server-docs.env
cp deploy/env/demo.env.example        deploy/env/demo.env
```

Real `*.env` files are gitignored; the `*.env.example` files are the templates,
and each one documents every variable, its values, and its default. The demo's
values are baked in at build time (Flutter web has no runtime env), so read
`env/demo.env.example` before building it.

## Run the whole stack locally

From the repo root:

```sh
docker compose -f deploy/docker-compose.yml up --build
```

Local ports: server `8080`, demo `8081`. Add `--profile docs` for the slim
docs/MCP server on `8084`, `--profile s3` for a local MinIO bucket, or
`--profile cron` for the cleanup timer.

To bake the demo against a specific API URL:

```sh
docker compose --env-file deploy/env/demo.env -f deploy/docker-compose.yml build fluvie-demo
```

## Deploy with Dokploy

Create one app per service, from these Dockerfiles (build context = repo root)
or from the published `ghcr.io/simonerich/*` images. For each app: set its
domain in the Dokploy **Domains** tab, paste the matching `env/*.env` contents
into the app's **Environment** (or **Build Arguments** for the demo), and let
Traefik own ports 80/443. The full checklist is in [../RELEASE.md](../RELEASE.md).
