/// The Fluvie render API server.
///
/// Pulls in `dart:io`, `shelf`, and `minio`, so it is NOT web-safe — a Flutter
/// app should import `package:fluvie_server/client.dart` instead. Use
/// `serverConfigFromEnvironment` + `buildServerDependencies` + `serveFluvieApi`
/// to start a server (see `bin/fluvie_server.dart`).
library;

export 'src/api/cleanup/retention_scheduler.dart';
export 'src/api/cleanup/retention_service.dart' show RetentionReport, RetentionService;
export 'src/api/config/s3_config.dart';
export 'src/api/config/server_config.dart';
export 'src/api/http/server_app.dart' show buildApp, serveFluvieApi;
export 'src/api/http/server_dependencies.dart';
export 'src/api/jobs/file_job_store.dart' show FileJobStore;
export 'src/api/server_factory.dart';
