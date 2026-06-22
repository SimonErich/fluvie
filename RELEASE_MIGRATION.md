# Migrating to `fluvie_server` (0.1.4)

In 0.1.4 the `fluvie_api` and `fluvie_mcp` packages and images were consolidated
into one package and one binary, **`fluvie_server`**, that hosts the render API,
the MCP server, and a new documentation helper. Each capability is toggled by an
environment variable, so you run one service instead of wiring up two.

**What did not change:** the `/v1` render routes, the `/mcp` JSON-RPC contract,
and every environment variable name. Existing API clients and remote MCP clients
keep working. The breaking parts are the **package names**, the **image names**,
and the **MCP run command**.

This is the operator checklist: what to delete, change, set, and add. Work top to
bottom; the in-repo changes (sections 1 to 4) already landed in this commit, so on
a fresh clone you only do the hosting steps (5 onward).

---

## 1. In this repository (already done)

For reference, the consolidation already changed in-repo:

- **Deleted:** `packages/fluvie_api/`, `packages/fluvie_mcp/`,
  `deploy/api.Dockerfile`, `deploy/mcp.Dockerfile`,
  `deploy/env/api.env.example`, `deploy/env/mcp.env.example`.
- **Added:** `packages/fluvie_server/`, `deploy/server.Dockerfile`,
  `deploy/server-docs.Dockerfile`, `deploy/env/server.env.example`,
  `deploy/env/server-docs.env.example`.
- **Changed:** the workspace list and coverage gate in `pubspec.yaml`, the
  `example/` dependency and its one client import, `.github/workflows/publish.yml`
  and `images.yml`, `deploy/docker-compose.yml`, and the docs.

## 2. Your local checkout

- **Delete** any local, gitignored env files you copied from the old templates:
  `deploy/env/api.env` and `deploy/env/mcp.env`.
- **Add** the new one from its template, and fill in the tokens:
  ```sh
  cp deploy/env/server.env.example deploy/env/server.env
  # optional, only for a separate slim docs endpoint:
  cp deploy/env/server-docs.env.example deploy/env/server-docs.env
  ```
- **Re-resolve** the workspace: `melos bootstrap`.

## 3. Code that depended on the old packages

- **Change** the dependency in any consumer `pubspec.yaml`:
  `fluvie_api` / `fluvie_mcp` → `fluvie_server`.
- **Change** imports:
  - `package:fluvie_api/client.dart` → `package:fluvie_server/client.dart`
  - `package:fluvie_api/server.dart` → `package:fluvie_server/server.dart`
  - any `package:fluvie_mcp/...` → the same symbol from `package:fluvie_server/...`

## 4. Run commands

| Was | Now |
| --- | --- |
| `dart run fluvie_api` (or the `fluvie_api` binary) | `fluvie_server` (HTTP, render API on by default) |
| `dart run fluvie_mcp` (stdio) | `fluvie_server --stdio` |
| `dart run fluvie_mcp --http` | `fluvie_server` (the HTTP server mounts MCP at `/mcp`) |

The MCP `--http` flag is gone: HTTP is the default run mode, and MCP is mounted at
`/mcp` whenever `FLUVIE_ENABLE_MCP` is not `false`. For a docs-only local helper
(no render backend), run `FLUVIE_ENABLE_API=false fluvie_server --stdio`.

## 5. pub.dev

- **Add (one-time):** `fluvie_server` is a brand-new package. Do a first manual
  publish before the tagged release, then enable automated publishing:
  ```sh
  cd packages/fluvie_server && dart pub publish
  ```
  Then on its pub.dev page, **Admin → Automated publishing**, set the tag pattern
  to `v{{version}}` (the umbrella tag, same as every other package).
- **Retire (optional):** mark `fluvie_api` and `fluvie_mcp` as **discontinued** on
  pub.dev so consumers see they moved. You cannot delete a published package; the
  old versions stay available, and the tagged release no longer republishes them.

## 6. Container images (ghcr.io)

- **Add:** the next `v0.1.4` tag builds `ghcr.io/simonerich/fluvie-server` and
  `ghcr.io/simonerich/fluvie-server-docs`. After the first push, set both GitHub
  **Packages** to **public**.
- **Delete:** the now-unused `ghcr.io/simonerich/fluvie-api` and
  `ghcr.io/simonerich/fluvie-mcp` packages.

## 7. GitHub Actions secrets

- **Add:** `DOKPLOY_WEBHOOK_SERVER`, `DOKPLOY_WEBHOOK_SERVER_DOCS`.
- **Delete:** `DOKPLOY_WEBHOOK_API`, `DOKPLOY_WEBHOOK_MCP` (no longer referenced
  by `images.yml`).
  ```sh
  gh secret set DOKPLOY_WEBHOOK_SERVER       --body 'https://<dokploy-host>/<webhook>'
  gh secret set DOKPLOY_WEBHOOK_SERVER_DOCS  --body 'https://<dokploy-host>/<webhook>'
  gh secret delete DOKPLOY_WEBHOOK_API
  gh secret delete DOKPLOY_WEBHOOK_MCP
  ```

## 8. Dokploy apps

Keep the same domains; repoint each app at the new image and set its webhook.

- **api.fluvie.dev** (was image `fluvie-api`):
  - **Change** the image to `ghcr.io/simonerich/fluvie-server:latest`.
  - **Keep** the env from `server.env` (`API_TOKEN`, `CLEANUP_TOKEN`,
    `PUBLIC_BASE_URL=https://api.fluvie.dev`, storage, AI key). The new
    `FLUVIE_ENABLE_*` toggles default on, so the API, MCP, and docs all serve from
    this one app at `/v1`, `/mcp`, and `/v1/docs`.
  - **Set** the redeploy webhook to `DOKPLOY_WEBHOOK_SERVER`.
- **mcp.fluvie.dev** (was image `fluvie-mcp`):
  - **Change** the image to `ghcr.io/simonerich/fluvie-server-docs:latest`.
  - **Set** `FLUVIE_API_URL=https://api.fluvie.dev`, `FLUVIE_API_TOKEN` (the API's
    token), and `FLUVIE_MCP_TOKEN` (what clients send). `FLUVIE_ENABLE_API=false`
    is baked into this image.
  - **Heads-up:** the slim server falls back to **docs mode** (docs tools only, no
    rendering) if `FLUVIE_API_URL` is unset. Set it to keep the render/author
    tools that the old `fluvie-mcp` always exposed.
  - **Set** the redeploy webhook to `DOKPLOY_WEBHOOK_SERVER_DOCS`.
- **demo.fluvie.dev:** unchanged.

Container ports are unchanged: `fluvie-server` and `fluvie-server-docs` listen on
`8080`, the demo on `80`.

> Simpler option: if you do not need a separate slim docs endpoint, drop the
> `mcp.fluvie.dev` app entirely and point clients at `https://api.fluvie.dev/mcp`
> (the full server already serves MCP there). Then you only run one app.

## 9. Environment variables

No variable was renamed. New optional toggles on `fluvie_server`:

| Variable | Default | Effect |
| --- | --- | --- |
| `FLUVIE_ENABLE_API` | `true` | Mount `/v1` (needs the render toolchain). |
| `FLUVIE_ENABLE_MCP` | `true` | Enable MCP (`/mcp` and `--stdio`). |
| `FLUVIE_ENABLE_DOCS` | `true` | Enable the documentation helper. |
| `FLUVIE_MCP_MODE` | `build` if a backend exists, else `docs` | Which MCP tools are exposed. |
| `FLUVIE_DOCS_DIR` | `/app/documentation` | Where docs markdown is read from. |

## 10. Cut the release

```sh
bash tool/set_version.sh 0.1.4   # bumps every pubspec to 0.1.4 and stamps the
                                 # package CHANGELOGs (it skips fluvie_server,
                                 # which already has a [0.1.4] section)
# edit the stamped CHANGELOG notes, commit, land on green main
cd packages/fluvie_server && dart pub publish   # first manual publish (one-time)
gh release create v0.1.4 --generate-notes        # fires publish.yml + images.yml
```

## Verify

- `melos bootstrap && CI=true melos run gate` (format, analyze, lint, coverage).
- `docker build -f deploy/server.Dockerfile -t fluvie-server .` then run it with
  `API_TOKEN`/`CLEANUP_TOKEN`; `curl /healthz`, `POST /mcp` `tools/list`, and a
  `POST /v1/renders` round-trip.
- `docker build -f deploy/server-docs.Dockerfile -t fluvie-server-docs .` then run
  it; `curl /v1/docs` and `POST /mcp` `tools/list` (docs tools, offline, ~50 MB).
- Existing clients: a `POST /v1/renders` from an old API client and a `/mcp` call
  from an existing MCP client both still work unchanged.
