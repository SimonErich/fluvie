/// The Fluvie render API server.
///
/// Pulls in `dart:io`, `shelf`, and `minio`, so it is NOT web-safe — a Flutter
/// app should import `package:fluvie_api/client.dart` instead. Use
/// `serverConfigFromEnvironment` + `buildServerDependencies` + `serveFluvieApi`
/// to start a server (see `bin/fluvie_api.dart`).
library;

export 'src/cleanup/retention_scheduler.dart';
export 'src/cleanup/retention_service.dart' show RetentionReport, RetentionService;
export 'src/config/s3_config.dart';
export 'src/config/server_config.dart';
export 'src/http/server_app.dart' show buildApp, serveFluvieApi;
export 'src/http/server_dependencies.dart';
export 'src/jobs/file_job_store.dart' show FileJobStore;
export 'src/server_factory.dart';
