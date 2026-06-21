import 'package:shelf/shelf.dart';

/// Handles `GET /`: a small, human-facing landing page for anyone who opens the
/// API host in a browser.
///
/// The API itself is JSON under `/v1`; this page exists so the bare domain is
/// not a bare `404`. It points at the docs, the source, and the live endpoints.
final class RootHandler {
  /// Creates the handler.
  const RootHandler();

  /// Serves the landing page as HTML.
  Response index(Request request) =>
      Response.ok(_html, headers: const {'content-type': 'text/html; charset=utf-8'});

  static const _html = '''
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Fluvie render API</title>
<style>
  :root { color-scheme: light dark; }
  body { font: 16px/1.6 system-ui, sans-serif; max-width: 42rem; margin: 4rem auto;
         padding: 0 1.25rem; }
  h1 { font-size: 1.6rem; margin-bottom: 0.25rem; }
  code { font-family: ui-monospace, monospace; background: rgba(127,127,127,0.18);
         padding: 0.1em 0.35em; border-radius: 4px; }
  ul { padding-left: 1.2rem; }
  li { margin: 0.35rem 0; }
  a { color: inherit; }
</style>
</head>
<body>
<h1>Fluvie render API</h1>
<p>This host renders declarative Flutter scenes to MP4. It is a JSON API; there is
no UI here. Point a client at the endpoints below.</p>
<h2>Endpoints</h2>
<ul>
  <li><code>POST /v1/renders</code> &mdash; queue a render (needs a bearer API token)</li>
  <li><code>GET /v1/renders/{id}</code> &mdash; poll a job and get download links</li>
  <li><code>GET /v1/files/{id}/{kind}</code> &mdash; download the video or poster</li>
  <li><code>GET /v1/schema/video-spec</code> &mdash; the VideoSpec JSON schema</li>
  <li><code>GET /v1/healthz</code> &middot; <code>GET /v1/readyz</code> &mdash; health probes</li>
</ul>
<h2>Learn more</h2>
<ul>
  <li>Guide: <a href="https://docs.fluvie.dev/guides/rendering-on-a-server">Rendering on a server</a></li>
  <li>Docs: <a href="https://docs.fluvie.dev">docs.fluvie.dev</a></li>
  <li>Source: <a href="https://github.com/SimonErich/fluvie">github.com/SimonErich/fluvie</a></li>
</ul>
</body>
</html>
''';
}
