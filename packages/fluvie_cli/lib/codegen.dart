/// The pure code-generation surface: the spec-to-Dart printer, alone.
///
/// The main `package:fluvie_cli/fluvie_cli.dart` barrel carries the whole
/// CLI, including `dart:io` process plumbing and the `dart:ffi` ABI probe
/// behind the FFmpeg cache, which a web build cannot compile. Import this
/// entrypoint instead where only the printer is needed — it stays pure
/// Dart (dart_style), so it runs everywhere, the browser included:
///
/// ```dart
/// import 'package:fluvie_cli/codegen.dart';
/// ```
library;

export 'src/codegen/dart_spec_printer.dart' show printVideoSpecJson;
