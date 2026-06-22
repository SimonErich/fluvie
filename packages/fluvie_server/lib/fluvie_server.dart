/// The Fluvie server: render API, AI authoring, MCP, and a documentation helper
/// in one binary, with each capability toggled by environment variables.
///
/// This barrel re-exports the server surface (`dart:io`, `shelf`, `minio`); it
/// is NOT web-safe. A Flutter app should import `package:fluvie_server/client.dart`
/// instead. The entrypoint lives in `bin/fluvie_server.dart`.
library;

export 'server.dart';
