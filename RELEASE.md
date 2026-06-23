# Releasing Fluvie

This is the operator checklist for shipping a Fluvie release and standing up the
hosted pieces. The code checks, the docs site, the pub.dev publishing, and the
container images are all automated in GitHub Actions. The steps below are the
parts that need your accounts and credentials.

## 0. What is automated

| Trigger | Workflow | Result |
| --- | --- | --- |
| push to `main` | `ci.yaml` | format, analyze, lint, tests, coverage, goldens, pana, render smoke |
| push to `main` (docs change) | `docs.yml` | builds the docs site (`web/docs`) and deploys it to GitHub Pages (docs.fluvie.dev) |
| push to `main` (`web/site` change) | `website.yml` | builds the landing (`web/site`, Astro) and publishes it to the `fluvie_website` repo, whose Pages serves fluvie.dev |
| tag `v0.1.0` (umbrella) | `publish.yml` | publishes every package to pub.dev via OIDC (one shared version) |
| tag `v0.1.0` (umbrella) | `images.yml` | builds and pushes the server/server-docs/demo images to ghcr.io, then pings the Dokploy redeploy webhooks |

One tag does everything: publish a GitHub Release for `v0.1.0` (or push the tag)
and pub.dev publishing, the image build, and the Dokploy redeploy all fire.

## 1. The hosting map

| Surface | Where it runs | How |
| --- | --- | --- |
| docs.fluvie.dev | **GitHub Pages** (free, this repo) | `docs.yml` builds `web/docs` and deploys |
| fluvie.dev (landing) | **GitHub Pages** (the `fluvie_website` repo) | `website.yml` builds `web/site` and publishes it there |
| demo.fluvie.dev | **Dokploy** | image `fluvie-demo` (static Flutter web) |
| api.fluvie.dev | **Dokploy** | image `fluvie-server` (the renderer) |
| mcp.fluvie.dev | **Dokploy** | image `fluvie-server-docs` |

GitHub Pages allows one custom domain per repo, so docs.fluvie.dev serves from
this repo and fluvie.dev serves from the separate `fluvie_website` repo. The API,
MCP, and demo services run as Dokploy containers.

## 2. One-time: pub.dev publishing

All packages share one version and publish from one umbrella tag, but pub.dev
must trust this repo first. For every package (`fluvie`, `fluvie_cli`,
`fluvie_lints`, `fluvie_ai`, `fluvie_server`, `fluvie_mobile_encoder`,
`fluvie_web_encoder`):

1. Reserve the name with a first manual publish from the package directory:
   ```sh
   cd packages/fluvie && dart pub publish
   ```
   Publish `fluvie` first, then `fluvie_cli`/`fluvie_lints`, then
   `fluvie_ai`/`fluvie_server` (later ones depend on the earlier ones).
2. On each package's pub.dev page, open **Admin → Automated publishing** and
   enable publishing from GitHub Actions for `SimonErich/fluvie` with the tag
   pattern **`v{{version}}`** (the umbrella tag — the same for every package, so
   one `v0.1.2` release publishes them all).

`fluvie_server` is new as of 0.1.4, so it has no Admin page yet: do its first
manual publish (`cd packages/fluvie_server && dart pub publish`) before the
tagged release, then set its tag pattern to `v{{version}}`. The retired
`fluvie_api` and `fluvie_mcp` packages are no longer in the workspace, so the
tagged release will not republish them; their existing pub.dev versions stay up
(pub.dev packages cannot be deleted). Optionally mark them **discontinued** on
pub.dev so consumers see they moved to `fluvie_server`.

## 3. One-time: GitHub Pages for docs.fluvie.dev

1. Repo **Settings → Pages → Build and deployment → Source: GitHub Actions**.
2. Push to `main`; the `docs` workflow builds Astro and deploys, writing the
   `docs.fluvie.dev` CNAME.
3. Add the DNS record (step 5), then set the custom domain under Settings → Pages.

## 4. One-time: container registry

The images publish to `ghcr.io/simonerich/<name>` using the built-in
`GITHUB_TOKEN`, so there is nothing to configure to push. After the first
`images` run, open each package under your GitHub **Packages** and set it to
**public** so anyone can pull without auth. Images: `fluvie-server`, `fluvie-server-docs`,
`fluvie-demo`. The old `fluvie-api` and `fluvie-mcp` images are no longer built;
delete those ghcr packages once the new ones are live.

## 5. DNS (your registrar)

| Host | Points at |
| --- | --- |
| `docs.fluvie.dev` | GitHub Pages (CNAME to `simonerich.github.io`) |
| `fluvie.dev` | GitHub Pages (CNAME to `simonerich.github.io`, served from `fluvie_website`) |
| `demo.fluvie.dev` | your Dokploy host (the `fluvie-demo` app) |
| `api.fluvie.dev` | your Dokploy host (the `fluvie-server` app) |
| `mcp.fluvie.dev` | your Dokploy host (the `fluvie-server-docs` app) |

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

The full server and the slim docs server listen on `8080` (override with `PORT`);
the demo is a static site behind nginx on `80`. Pointing a domain at the
wrong port is what yields a Bad Gateway.

- **api.fluvie.dev** (`fluvie-server`, `deploy/server.Dockerfile`): set `API_TOKEN` and
  `CLEANUP_TOKEN`. For server-side AI also set `ANTHROPIC_API_KEY` (or another
  provider key); leave it unset to keep prompt-based renders off. Add a volume for
  `/data/renders`, or configure S3 (see `deploy/env/server.env.example`). Set
  `PUBLIC_BASE_URL=https://api.fluvie.dev`.
- **mcp.fluvie.dev** (`fluvie-server-docs`, `deploy/server-docs.Dockerfile`): set
  `FLUVIE_API_URL=https://api.fluvie.dev`, `FLUVIE_API_TOKEN` to the API token, and
  `FLUVIE_MCP_TOKEN` to a token clients must send.
- **demo.fluvie.dev** (`fluvie-demo`, `deploy/demo.Dockerfile`): the API URL is
  baked in at build time. The published image points at `https://api.fluvie.dev`;
  to target another API, rebuild with `--build-arg FLUVIE_API_URL=...`.

### Auto-redeploy on a new image

After `images.yml` pushes the images, it pings a Dokploy deploy webhook for each
service so server, server-docs, and demo redeploy themselves. To enable it:

1. In Dokploy, open each app and copy its **Webhook URL** (the deploy/auto-deploy
   webhook under the app's settings).
2. Point each app's image at a moving tag so the redeploy pulls the new build:
   `ghcr.io/simonerich/fluvie-server:latest` (or `:0.1`). A pinned `:0.1.0` would
   just re-pull the old image.
3. Store the URLs as repo secrets (Settings -> Secrets and variables -> Actions),
   or with the CLI:
   ```sh
   gh secret set DOKPLOY_WEBHOOK_SERVER  --body 'https://<dokploy-host>/<webhook-path>'
   gh secret set DOKPLOY_WEBHOOK_SERVER_DOCS  --body 'https://<dokploy-host>/<webhook-path>'
   gh secret set DOKPLOY_WEBHOOK_DEMO --body 'https://<dokploy-host>/<webhook-path>'
   ```

A secret left unset just skips that service, so the release never fails on a
missing webhook. (`fluvie.dev` is served by GitHub Pages via `website.yml`, not
Dokploy, so it has no redeploy webhook.)

### Keeping the public demo cheap and safe

The demo renders through `api.fluvie.dev`. To keep cost and abuse down:

- To enable the AI Assistant on the public API, set a provider key (for example
  `ANTHROPIC_API_KEY`) plus `FLUVIE_AI_MODEL` pinned to a cheap model
  (for example `claude-haiku-...`). This reverses the earlier guidance to leave
  the key unset: a per-IP quota now bounds the cost, so the demo can author from a
  prompt on your key. Leave the key unset to keep prompt-based renders off; spec
  and code renders still work.
- Tune the AI quota with `FLUVIE_AI_RATE_LIMIT` (calls per window, default 5),
  `FLUVIE_AI_RATE_WINDOW` (default `1m`), and `FLUVIE_AI_DAILY_QUOTA` (per UTC
  day, default 50). These apply to the prompt/edit path only. A request over a
  limit returns `429` with a `Retry-After` header.
- Keep `RENDER_CONCURRENCY=1` and a short `FILE_TTL`.
- Put the API behind Dokploy/Traefik rate limiting if you expose it widely.

## 7. Cut a release

All packages move together. Three steps:

```sh
bash tool/set_version.sh 0.1.2   # 1. set every package to 0.1.2
#                                  2. update the CHANGELOGs, commit, land on green main
gh release create v0.1.2 --generate-notes   # 3. publish the GitHub Release
```

Creating the release (step 3, or just `git push origin v0.1.2`) is the only
trigger you need. The `v0.1.2` tag fires both `publish.yml` (every package to
pub.dev) and `images.yml` (build the images, then ping the Dokploy redeploy
webhooks). You can also create the release from the GitHub **Releases** UI.

Notes:

- The version must be **new on pub.dev** for every package — a release republishes
  all of them, so bump it each time. A version already on pub.dev fails that
  package's publish job (the others still succeed).
- Do this from a real account, not an Action: GitHub does not fire `publish.yml` /
  `images.yml` for a tag pushed by the built-in `GITHUB_TOKEN`.
- Inter-package constraints are intentionally loose (`^0.1.x`) so the publish jobs
  can run in parallel. If you tighten them, add `needs:` ordering in `publish.yml`.

## 8. Optional polish

- Enable **Discussions** (Settings → General → Features) for the community link.
- Set your handle in `.github/FUNDING.yml` to show the Sponsor button.

## Local dry run

```sh
# the services (server :8080, demo :8081; slim docs server :8084 with --profile docs)
cp deploy/env/server.env.example deploy/env/server.env   # set API_TOKEN and CLEANUP_TOKEN
docker compose -f deploy/docker-compose.yml up --build

# the docs site
npm --prefix web/docs install
npm --prefix web/docs run dev            # http://localhost:4321
```
