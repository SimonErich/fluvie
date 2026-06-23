import 'dart:convert';
import 'dart:io';

import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/process_runner.dart';

/// The marker the capture harness prints before its unknown-key message so the
/// CLI can surface a friendly error instead of the raw flutter-test tail.
const String runCaptureUnknownKeyMarker = 'fluvie-unknown-key:';

/// Locates the Flutter project hosting the capture harness.
///
/// An explicit [project] is used verbatim. Otherwise the harness is
/// auto-discovered by walking up from [cwd] (default: [Directory.current]),
/// checking two layouts at each level:
///
/// 1. a standalone project (for example one scaffolded by `fluvie init`) whose
///    harness sits directly under its own `test/render/`, and
/// 2. the Fluvie monorepo, whose harness lives in the bundled `example` project.
///
/// So the CLI works from a scaffolded project root, from the repo root, and from
/// inside `packages/fluvie_cli` alike.
String resolveProjectDir({String? project, Directory? cwd}) {
  if (project != null) return project;
  const harness = 'test/render/capture_harness_test.dart';
  var dir = (cwd ?? Directory.current).absolute;
  while (true) {
    if (File('${dir.path}/$harness').existsSync()) return dir.path;
    final example = '${dir.path}/example';
    if (File('$example/$harness').existsSync()) return example;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw const CliFailure(
        'Could not find a Fluvie capture harness '
        '(test/render/capture_harness_test.dart) in the working directory, its '
        '"example" project, or any parent. Run `fluvie init` to scaffold a '
        'project, or pass --project pointing at the Flutter project to capture '
        'from.',
      );
    }
    dir = parent;
  }
}

/// The exact `flutter` argument array driving one capture: the permanent
/// harness test, parameterized by `--dart-define`s.
///
/// [aspect]/[quality]/[format]/[poster] are the export defines. They are
/// already validated by the command layer; absent values omit their define so
/// a plain `fluvie render` stays byte-identical to a capture without them.
///
/// [impeller] adds `flutter test`'s `--enable-impeller` flag so the capture
/// rasterizes with Impeller instead of the default tester backend. It is off by
/// default, so an ordinary render is unchanged; turn it on (via the render
/// `--enable-impeller` flag) when an effect needs the Impeller pipeline.
///
/// [harnessPath] is the test `flutter test` JIT-compiles and runs, relative to
/// the project directory. It defaults to the permanent capture harness, so an
/// ordinary render is byte-identical; the Playground points it at a generated
/// per-render harness that statically imports the user's `input.dart`.
List<String> captureTestArgs({
  required String key,
  required Directory sandbox,
  int? frames,
  bool noCache = false,
  bool impeller = false,
  String? aspect,
  String? quality,
  String? format,
  String? poster,
  String harnessPath = 'test/render/capture_harness_test.dart',
  Map<String, String> extraDefines = const {},
}) => [
  'test',
  '--no-pub',
  if (impeller) '--enable-impeller',
  harnessPath,
  '--dart-define=FLUVIE_RENDER_KEY=$key',
  '--dart-define=FLUVIE_RENDER_OUT_DIR=${sandbox.path}',
  if (frames != null) '--dart-define=FLUVIE_RENDER_FRAMES=$frames',
  if (noCache) '--dart-define=FLUVIE_RENDER_NO_CACHE=true',
  if (aspect != null) '--dart-define=FLUVIE_RENDER_ASPECT=$aspect',
  if (quality != null) '--dart-define=FLUVIE_RENDER_QUALITY=$quality',
  if (format != null) '--dart-define=FLUVIE_RENDER_FORMAT=$format',
  if (poster != null) '--dart-define=FLUVIE_RENDER_POSTER=$poster',
  for (final define in extraDefines.entries) '--dart-define=${define.key}=${define.value}',
];

/// Runs the capture step: `flutter test` on the harness inside [projectDir],
/// rendering composition [key] into [sandbox].
///
/// With [verbose] the captured flutter-test output is forwarded to [err]
/// (this is where the harness's `cache hits` report surfaces). A non-zero
/// exit throws a [CliFailure] carrying the test output, so harness failure
/// text (for example the unknown-key message) reaches the user. A `flutter`
/// binary that cannot be spawned at all surfaces as a [CliFailure] with an
/// install hint, never as a raw [ProcessException].
///
/// [environment] is added on top of the harness's inherited environment, so a
/// caller (the server) can hand each capture a unique `FLUVIE_PROGRESS_FILE`
/// and the AI API keys without a shell. When it is `null` the harness simply
/// inherits this process's environment, as the CLI commands rely on.
Future<void> runCapture({
  required ProcessRunner runner,
  required String projectDir,
  required String key,
  required Directory sandbox,
  required StringSink err,
  int? frames,
  bool noCache = false,
  bool impeller = false,
  bool verbose = false,
  String? aspect,
  String? quality,
  String? format,
  String? poster,
  String harnessPath = 'test/render/capture_harness_test.dart',
  Map<String, String> extraDefines = const {},
  Map<String, String>? environment,
}) async {
  final args = captureTestArgs(
    key: key,
    sandbox: sandbox,
    frames: frames,
    noCache: noCache,
    impeller: impeller,
    aspect: aspect,
    quality: quality,
    format: format,
    poster: poster,
    harnessPath: harnessPath,
    extraDefines: extraDefines,
  );
  final ProcessRunResult result;
  try {
    // Only forward `environment` when given, so an inherit-only capture stays a
    // plain two-argument run (and keeps the CLI's behavior byte-identical).
    result = environment == null
        ? await runner.run('flutter', args, workingDirectory: projectDir)
        : await runner.run(
            'flutter',
            args,
            workingDirectory: projectDir,
            environment: environment,
          );
  } on ProcessException catch (error) {
    throw CliFailure(
      'Could not run "flutter test" in "$projectDir" (${error.message}). Install Flutter and '
      'make sure `flutter` is on PATH (https://docs.flutter.dev/get-started/install), or pass '
      '--project pointing at a project whose toolchain is set up.',
    );
  }
  if (verbose) {
    err
      ..writeln(result.stdout)
      ..writeln(result.stderr);
  }
  if (result.exitCode != 0) {
    final friendly = _unknownKeyMessage(result.stdout) ?? _unknownKeyMessage(result.stderr);
    if (friendly != null) {
      throw CliFailure('$friendly\nRun `fluvie list` to see valid keys.');
    }
    throw CliFailure(
      'The capture step (flutter test in "$projectDir") failed with exit code '
      '${result.exitCode}.\n${_tail(result.stdout)}\n${_tail(result.stderr)}',
    );
  }
}

/// The harness's unknown-key message parsed out of [output] (the text after
/// [runCaptureUnknownKeyMarker] on its line), or `null` when the marker is
/// absent so an ordinary failure keeps its raw tail.
String? _unknownKeyMessage(String output) {
  for (final line in const LineSplitter().convert(output)) {
    final index = line.indexOf(runCaptureUnknownKeyMarker);
    if (index < 0) continue;
    final message = line.substring(index + runCaptureUnknownKeyMarker.length).trim();
    if (message.isNotEmpty) return message;
  }
  return null;
}

/// Keeps the last 4 KiB of [output] for diagnostics.
String _tail(String output) =>
    output.length <= 4096 ? output : output.substring(output.length - 4096);
