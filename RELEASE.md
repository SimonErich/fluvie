# Releasing Fluvie

This is the operator checklist for shipping a Fluvie release and standing up the
hosted pieces. The code checks, the docs site, the pub.dev publishing, and the
container images are all automated in GitHub Actions. The steps below are the
parts that need your accounts and credentials.

## 0. What is automated

| Trigger | Workflow | Result |
| --- | --- | --- |
| push to `main` | `ci.yaml` | format, analyze, lint, tests, coverage, goldens, pana, render smoke |
| push to `main` (docs change) | `docs.yml` | builds the Astro site and deploys it to GitHub Pages |
| tag `fluvie-v0.1.0` (per package) | `publish.yml` | publishes that package to pub.dev via OIDC |
| tag `v0.1.0` (umbrella) | `images.yml` | builds and pushes the service images to ghcr.io, then pings the Dokploy redeploy webhooks |

## 1. The hosting map

| Surface | Where it runs | How |
| --- | --- | --- |
| docs.fluvie.dev | **GitHub Pages** (free, this repo) | `docs.yml` builds `web/docs` and deploys |
| fluvie.dev (landing) | **Dokploy** | image `fluvie-web` |
| demo.fluvie.dev | **Dokploy** | image `fluvie-demo` (static Flutter web) |
| api.fluvie.dev | **Dokploy** | image `fluvie-api` (the renderer) |
| mcp.fluvie.dev | **Dokploy** | image `fluvie-mcp` |

GitHub Pages allows one custom domain per repo, which is why only the docs use it
and the other static sites run as Dokploy containers.

## 2. One-time: pub.dev publishing

Each package publishes when you push its tag, but pub.dev must trust this repo
first. For every package (`fluvie`, `fluvie_cli`, `fluvie_lints`, `fluvie_ai`,
`fluvie_api`, `fluvie_mcp`):

1. Reserve the name with a first manual publish from the package directory:
   ```sh
   cd packages/fluvie && dart pub publish
   ```
   Publish `fluvie` first, then `fluvie_cli`/`fluvie_lints`, then
   `fluvie_ai`/`fluvie_api`/`fluvie_mcp` (later ones depend on the earlier ones).
2. On each package's pub.dev page, open **Admin → Automated publishing** and
   enable publishing from GitHub Actions for `SimonErich/fluvie` with the tag
   pattern `{{package}}-v{{version}}` (for example `fluvie-v{{version}}`).

## 3. One-time: GitHub Pages for docs.fluvie.dev

1. Repo **Settings → Pages → Build and deployment → Source: GitHub Actions**.
2. Push to `main`; the `docs` workflow builds Astro and deploys, writing the
   `docs.fluvie.dev` CNAME.
3. Add the DNS record (step 5), then set the custom domain under Settings → Pages.

## 4. One-time: container registry

The images publish to `ghcr.io/simonerich/<name>` using the built-in
`GITHUB_TOKEN`, so there is nothing to configure to push. After the first
`images` run, open each package under your GitHub **Packages** and set it to
**public** so anyone can pull without auth. Images: `fluvie-api`, `fluvie-mcp`,
`fluvie-demo`, `fluvie-web`.

## 5. DNS (your registrar)

| Host | Points at |
| --- | --- |
| `docs.fluvie.dev` | GitHub Pages (CNAME to `simonerich.github.io`) |
| `fluvie.dev` | your Dokploy host (the `fluvie-web` app) |
| `demo.fluvie.dev` | your Dokploy host (the `fluvie-demo` app) |
| `api.fluvie.dev` | your Dokploy host (the `fluvie-api` app) |
| `mcp.fluvie.dev` | your Dokploy host (the `fluvie-mcp` app) |

## 6. Deploy the services with Dokploy

Create one app per image. Pull `ghcr.io/simonerich/<name>:0.1.0`, or build from
this repo's Dockerfiles under `deploy/` (build context is the repo root). Set the
domain in the Dokploy **Domains** tab and let Traefik handle TLS. Do not publish
ports 80/443 yourself.

In the **Domains** tab, set **Container Port** to the port the service listens on
*inside* the container. Traefik connects over the Docker network, so this is the
container's port, not a host port. The local `docker-compose.yml` host ports
(8081, 8082, 8084) do not apply here:

| App | Container port |
| --- | --- |
| api.fluvie.dev | `8080` |
| mcp.fluvie.dev | `8080` |
| demo.fluvie.dev | `80` |
| fluvie.dev | `80` |

The render API and the MCP server listen on `8080` (override with `PORT`); the
demo and landing are static sites behind nginx on `80`. Pointing a domain at the
wrong port is what yields a Bad Gateway.

- **api.fluvie.dev** (`fluvie-api`, `deploy/api.Dockerfile`): set `API_TOKEN` and
  `CLEANUP_TOKEN`. For server-side AI also set `ANTHROPIC_API_KEY` (or another
  provider key); leave it unset to keep prompt-based renders off. Add a volume for
  `/data/renders`, or configure S3 (see `deploy/env/api.env.example`). Set
  `PUBLIC_BASE_URL=https://api.fluvie.dev`.
- **mcp.fluvie.dev** (`fluvie-mcp`, `deploy/mcp.Dockerfile`): set
  `FLUVIE_API_URL=https://api.fluvie.dev`, `FLUVIE_API_TOKEN` to the API token, and
  `FLUVIE_MCP_TOKEN` to a token clients must send.
- **demo.fluvie.dev** (`fluvie-demo`, `deploy/demo.Dockerfile`): the API URL is
  baked in at build time. The published image points at `https://api.fluvie.dev`;
  to target another API, rebuild with `--build-arg FLUVIE_API_URL=...`.
- **fluvie.dev** (`fluvie-web`, `deploy/landing.Dockerfile`): static, no config.

### Auto-redeploy on a new image

After `images.yml` pushes the images, it pings a Dokploy deploy webhook for each
service so api, mcp, and demo redeploy themselves. To enable it:

1. In Dokploy, open each app and copy its **Webhook URL** (the deploy/auto-deploy
   webhook under the app's settings).
2. Point each app's image at a moving tag so the redeploy pulls the new build:
   `ghcr.io/simonerich/fluvie-api:latest` (or `:0.1`). A pinned `:0.1.0` would
   just re-pull the old image.
3. Store the URLs as repo secrets (Settings -> Secrets and variables -> Actions),
   or with the CLI:
   ```sh
   gh secret set DOKPLOY_WEBHOOK_API  --body 'https://<dokploy-host>/<webhook-path>'
   gh secret set DOKPLOY_WEBHOOK_MCP  --body 'https://<dokploy-host>/<webhook-path>'
   gh secret set DOKPLOY_WEBHOOK_DEMO --body 'https://<dokploy-host>/<webhook-path>'
   ```

A secret left unset just skips that service, so the release never fails on a
missing webhook. (`fluvie.dev` uses the separate `notify-website` flow.)

### Keeping the public demo cheap and safe

The demo renders through `api.fluvie.dev`. To keep cost and abuse down:

- Do not set a provider key on the public API, so the AI tools stay off there.
  The demo still renders the built-in lessons and any spec it is given.
- Keep `RENDER_CONCURRENCY=1` and a short `FILE_TTL`.
- Put the API behind Dokploy/Traefik rate limiting if you expose it widely.

## 7. Cut a release

From a green `main`:

```sh
# pub.dev packages (each tag publishes one package)
git tag fluvie-v0.1.0       && git push origin fluvie-v0.1.0
git tag fluvie_cli-v0.1.0   && git push origin fluvie_cli-v0.1.0
git tag fluvie_lints-v0.1.0 && git push origin fluvie_lints-v0.1.0
git tag fluvie_ai-v0.1.0    && git push origin fluvie_ai-v0.1.0
git tag fluvie_api-v0.1.0   && git push origin fluvie_api-v0.1.0
git tag fluvie_mcp-v0.1.0   && git push origin fluvie_mcp-v0.1.0

# the umbrella release tag (builds and pushes the container images)
git tag v0.1.0 && git push origin v0.1.0
```

Then create the GitHub Release for `v0.1.0` with notes from `CHANGELOG.md`.

## 8. Optional polish

- Enable **Discussions** (Settings → General → Features) for the community link.
- Set your handle in `.github/FUNDING.yml` to show the Sponsor button.

## Local dry run

```sh
# the services (api :8080, demo :8081, landing :8082, mcp :8084)
cp deploy/env/api.env.example deploy/env/api.env   # set API_TOKEN and CLEANUP_TOKEN
cp deploy/env/mcp.env.example deploy/env/mcp.env
docker compose -f deploy/docker-compose.yml up --build

# the docs site
npm --prefix web/docs install
npm --prefix web/docs run dev            # http://localhost:4321
```
