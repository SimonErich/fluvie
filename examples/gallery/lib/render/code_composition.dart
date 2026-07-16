import 'package:fluvie/fluvie.dart';
import 'package:fluvie_example/render/composition_entry.dart';

/// Builds a [CompositionEntry] from a user-supplied `Video build()` [builder].
CompositionEntry compositionFromVideo(Video Function() builder) =>
    CompositionEntry(key: 'code', video: builder);

/// The Dart source of a generated, per-render Playground capture harness.
///
/// `flutter test` JIT-compiles the file it is pointed at and its imports, so the
/// server writes this source next to the user's snippet ([inputImport], default
/// `input.dart`) and runs it. The harness statically imports the snippet — the
/// only way to load arbitrary code in a pre-built tester — builds a
/// [CompositionEntry] from its top-level `Video build()`, and drives the shared
/// `runCaptureHarness` exactly like the permanent harness does.
///
/// [harnessHelperDir] is the directory (relative to the generated file) holding
/// the test-tree `render_harness.dart`; the default climbs out of a
/// `<project>/.fluvie_playground/<id>/` directory back to `test/render/`.
///
/// This is a pure function (no IO) so the template is unit-tested without a
/// Flutter toolchain. The user contract: a zero-arg, synchronous top-level
/// `Video build()` returning a `Video`, importing only the Playground allowlist.
String playgroundHarnessSource({
  String inputImport = 'input.dart',
  String harnessHelperDir = '../../test/render',
}) =>
    '''
// GENERATED Playground capture harness — do not edit. One per render; deleted
// after the render completes. It statically imports the user snippet so
// `flutter test` JIT-compiles it, then drives the shared capture pipeline.

import 'dart:io';

import 'package:alchemist/alchemist.dart' show loadFonts;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie_example/render/code_composition.dart';

import '$harnessHelperDir/render_harness.dart';

import '$inputImport' as user;

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

    // Real bundled fonts (not the Ahem test font), matching the permanent harness.
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
