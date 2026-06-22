import 'dart:io';
import 'dart:math';

import 'package:fluvie_cli/fluvie_cli.dart' show resolveProjectDir;
import 'package:fluvie_server/src/api/render/code_import_policy.dart';
import 'package:fluvie_server/src/api/render/render_runner.dart';

/// One staged Playground render: the generated [dir] under the project's
/// `.fluvie_playground/`, the [harnessPath] to pass `flutter test` (relative to
/// the project root), and a [cleanup] that removes the directory.
final class StagedCodeRender {
  /// Creates a staged render.
  const StagedCodeRender({
    required this.projectDir,
    required this.dir,
    required this.harnessPath,
  });

  /// The project root the render runs under (the working directory for `flutter
  /// test`); [harnessPath] is relative to it.
  final String projectDir;

  /// The unique per-render directory holding `input.dart` + `harness_test.dart`.
  final Directory dir;

  /// The generated harness path, relative to [projectDir], for `flutter test`
  /// (which runs with the project as its working directory).
  final String harnessPath;

  /// Deletes [dir] (and its contents); a no-op if it is already gone.
  void cleanup() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}

/// Stages an untrusted Playground snippet for capture under [projectDir].
///
/// Enforces the import allowlist FIRST (throwing [CodeImportException] before
/// touching the disk), then writes the snippet to `input.dart` and a generated
/// harness to `harness_test.dart` in a fresh unique directory under
/// `<projectDir>/.fluvie_playground/`. The harness statically imports the
/// snippet so `flutter test` JIT-compiles it.
///
/// Per-render isolation is by directory only here. Per-render container
/// isolation (gVisor or equivalent) is the recommended hardening before
/// exposing this to anonymous public traffic, and is out of scope.
StagedCodeRender stageCodeRender({required String projectDir, required String code}) {
  final disallowed = disallowedImports(code);
  if (disallowed.isNotEmpty) throw CodeImportException(disallowed);

  final id = _uniqueId();
  final relativeDir = '.fluvie_playground/$id';
  final dir = Directory('$projectDir/$relativeDir')..createSync(recursive: true);
  File('${dir.path}/input.dart').writeAsStringSync(code);
  File('${dir.path}/harness_test.dart').writeAsStringSync(_harnessSource);
  return StagedCodeRender(
    projectDir: projectDir,
    dir: dir,
    harnessPath: '$relativeDir/harness_test.dart',
  );
}

/// Stages a code render under the render project (auto-discovered from
/// [renderProject]), mapping a disallowed import to a client-safe
/// [RenderFailure] — the defensive, in-runner half of the import allowlist the
/// handler already gated.
StagedCodeRender stageCodeRenderOrFail({required String? renderProject, required String code}) {
  try {
    return stageCodeRender(
      projectDir: resolveProjectDir(project: renderProject),
      code: code,
    );
  } on CodeImportException catch (error) {
    throw RenderFailure(error.message);
  }
}

final _random = Random.secure();

String _uniqueId() {
  final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final salt = _random.nextInt(1 << 32).toRadixString(36);
  return '$stamp$salt';
}

// The generated harness source. This mirrors `playgroundHarnessSource` in
// example/lib/render/code_composition.dart (the example tests that copy); both
// build the entry via `compositionFromVideo(user.build)` and drive the shared
// `runCaptureHarness`, reading the same FLUVIE_RENDER_* defines as the permanent
// harness. The render_harness helper lives in the example test tree, reached by
// a relative import that climbs out of `.fluvie_playground/<id>/`.
const String _harnessSource = '''
// GENERATED Playground capture harness — do not edit. Written per render and
// deleted afterward. It statically imports the user snippet so `flutter test`
// JIT-compiles it, then drives the shared capture pipeline.

import 'dart:io';

import 'package:alchemist/alchemist.dart' show loadFonts;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_example/render/code_composition.dart';

import '../../test/render/render_harness.dart';

import 'input.dart' as user;

const String _outDir = String.fromEnvironment('FLUVIE_RENDER_OUT_DIR');
const String _frames = String.fromEnvironment('FLUVIE_RENDER_FRAMES');
const String _noCache = String.fromEnvironment('FLUVIE_RENDER_NO_CACHE');
const String _aspect = String.fromEnvironment('FLUVIE_RENDER_ASPECT');
const String _quality = String.fromEnvironment('FLUVIE_RENDER_QUALITY');
const String _format = String.fromEnvironment('FLUVIE_RENDER_FORMAT');
const String _poster = String.fromEnvironment('FLUVIE_RENDER_POSTER');

void main() {
  testWidgets('the Playground harness renders the submitted snippet', (tester) async {
    expect(_outDir, isNotEmpty, reason: 'FLUVIE_RENDER_OUT_DIR must point at the sandbox');
    await loadFonts();

    final entry = compositionFromVideo(user.build);
    final noCache = bool.tryParse(_noCache) ?? false;
    final progressFile = Platform.environment['FLUVIE_PROGRESS_FILE'];

    await runCaptureHarness(
      tester: tester,
      entry: entry,
      outDir: Directory(_outDir),
      frameCountOverride: _frames.isEmpty ? null : int.parse(_frames),
      cacheEnabled: !noCache,
      export: parseExportFormat(_format),
      quality: parseQuality(_quality),
      aspect: parseAspect(_aspect),
      posterTime: parsePosterTime(_poster),
      progressFile: progressFile == null || progressFile.isEmpty ? null : progressFile,
    );
    // Untrusted code: a bounded per-test timeout (not Timeout.none) so a runaway
    // build() is killed by flutter test, under the runner's wall-clock ceiling.
  }, timeout: const Timeout(Duration(minutes: 6)));
}
''';
