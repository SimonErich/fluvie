// The permanent capture harness (decision D2): driven by the fluvie CLI via
// --dart-define; a plain `flutter test` run skips it, keeping the suite green
// without any melos exclusion.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_example/render/ai_authoring.dart';
import 'package:fluvie_example/render/composition_entry.dart';
import 'package:fluvie_example/render/composition_registry.dart';
import 'package:fluvie_example/render/spec_composition.dart';

import 'poster_capture.dart';
import 'render_harness.dart';

const String _key = String.fromEnvironment('FLUVIE_RENDER_KEY');
const String _outDir = String.fromEnvironment('FLUVIE_RENDER_OUT_DIR');
const String _frames = String.fromEnvironment('FLUVIE_RENDER_FRAMES');
const String _noCache = String.fromEnvironment('FLUVIE_RENDER_NO_CACHE');
const String _list = String.fromEnvironment('FLUVIE_RENDER_LIST');
const String _aspect = String.fromEnvironment('FLUVIE_RENDER_ASPECT');
const String _quality = String.fromEnvironment('FLUVIE_RENDER_QUALITY');
const String _format = String.fromEnvironment('FLUVIE_RENDER_FORMAT');
const String _poster = String.fromEnvironment('FLUVIE_RENDER_POSTER');
const String _spec = String.fromEnvironment('FLUVIE_RENDER_SPEC');
const String _prompt = String.fromEnvironment('FLUVIE_AI_PROMPT');
const String _baseSpec = String.fromEnvironment('FLUVIE_AI_BASE_SPEC');
const String _specOut = String.fromEnvironment('FLUVIE_RENDER_SPEC_OUT');

void main() {
  testWidgets('the capture harness renders the keyed composition', (tester) async {
    // `fluvie list` mode: print the keys behind the marker the CLI parses, then
    // skip the render entirely.
    if (bool.tryParse(_list) ?? false) {
      stdout.writeln('fluvie-keys: ${knownCompositionKeys.join(', ')}');
      return;
    }
    if (_key.isEmpty && _spec.isEmpty && _prompt.isEmpty) {
      markTestSkipped(
        'No FLUVIE_RENDER_KEY/SPEC/AI_PROMPT define: the capture harness only '
        'runs when the fluvie CLI drives it.',
      );
      return;
    }
    expect(_outDir, isNotEmpty, reason: 'FLUVIE_RENDER_OUT_DIR must point at the CLI sandbox');

    // Resolve the composition from one of three sources, in precedence order:
    // an AI prompt (`generate`/`edit`), a spec file (`render --spec`), or a
    // registry key (`render <key>`). The AI call runs in runAsync (network)
    // before the deterministic frame loop.
    CompositionEntry? entry;
    if (_prompt.isNotEmpty) {
      // For an edit (a base spec is present), render its poster so the model can
      // ground the change visually (conversational refinement).
      final lastFrame = _baseSpec.isEmpty
          ? null
          : await renderPosterPng(tester: tester, spec: videoSpecFromFile(_baseSpec));
      await tester.runAsync(() async {
        entry = await authorComposition(
          prompt: _prompt,
          specOut: _specOut,
          basePath: _baseSpec,
          lastFrame: lastFrame,
        );
      });
    } else if (_spec.isNotEmpty) {
      entry = compositionFromSpecFile(_spec);
    } else {
      entry = compositionForKey(_key);
      if (entry == null) {
        // Print the message behind the marker the CLI parses so `fluvie render`
        // surfaces a friendly unknown-key error, then fail the test.
        stdout.writeln('fluvie-unknown-key: ${unknownKeyMessage(_key)}');
        fail(unknownKeyMessage(_key));
      }
    }

    // Parsed at runtime on purpose: a const here would make the argument
    // below trip avoid_redundant_argument_values when the define is absent.
    final noCache = bool.tryParse(_noCache) ?? false;

    // The launcher passes a progress-file path through the process environment
    // (it survives `flutter test` into Platform.environment); the harness writes
    // live frame progress there for the launcher to poll. Absent for a plain
    // `flutter test` run, so nothing is written.
    final progressFile = Platform.environment['FLUVIE_PROGRESS_FILE'];

    await runCaptureHarness(
      tester: tester,
      entry: entry!,
      outDir: Directory(_outDir),
      frameCountOverride: _frames.isEmpty ? null : int.parse(_frames),
      cacheEnabled: !noCache,
      export: parseExportFormat(_format),
      quality: parseQuality(_quality),
      aspect: parseAspect(_aspect),
      posterTime: parsePosterTime(_poster),
      progressFile: progressFile == null || progressFile.isEmpty ? null : progressFile,
    );
  }, timeout: Timeout.none);
}
