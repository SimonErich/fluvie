# Deploying Fluvie

Everything needed to run the Fluvie services as containers lives here. The
documentation site (docs.fluvie.dev) is hosted on GitHub Pages, not from this
folder.

## Services

| Service | Dockerfile | Env file | Container port | Domain |
| --- | --- | --- | --- | --- |
| `fluvie-api` | `api.Dockerfile` | `env/api.env` | 8080 | api.fluvie.dev |
| `fluvie-mcp` | `mcp.Dockerfile` | `env/mcp.env` | 8080 | mcp.fluvie.dev |
| `fluvie-demo` | `demo.Dockerfile` | `env/demo.env` (build-time) | 80 | demo.fluvie.dev |
| `fluvie-web` | `landing.Dockerfile` | none | 80 | fluvie.dev |

All build contexts are the repo root; the Dockerfiles just live under `deploy/`.

## Env files

Each service has its own documented template under `env/`. Copy and edit:

```sh
cp deploy/env/api.env.example  deploy/env/api.env
cp deploy/env/mcp.env.example  deploy/env/mcp.env
cp deploy/env/demo.env.example deploy/env/demo.env
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

Local ports: api `8080`, demo `8081`, landing `8082`, mcp `8084`. Add
`--profile s3` for a local MinIO bucket, or `--profile cron` for the cleanup
timer.

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
