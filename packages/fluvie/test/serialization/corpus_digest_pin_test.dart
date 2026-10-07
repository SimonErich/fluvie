import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show VideoSpec;

/// The literal digest of every corpus fixture.
///
/// `corpus_test.dart` proves a digest is *stable across a round-trip*, which
/// catches a broken encoder but says nothing about whether today's engine
/// renders what yesterday's engine rendered. This table is the other half: it
/// pins the exact value, so any change that moves a document's canonical JSON
/// turns red here and names the fixture that moved.
///
/// A red test is not automatically a bug. It means exactly one of two things:
///
/// * an unintended change reached the spec surface, and the fix is in the code;
/// * a deliberate format change landed, and the fix is to update the value in
///   the same commit, so the diff records that the render moved.
///
/// Never update a value to make the suite pass without deciding which it was.
const Map<String, String> _corpusDigests = {
  'annotations.fluvie.json': '5fa431a5a1dc3340',
  'audio_automation.fluvie.json': '5756835653afcbde',
  'encoder_options.fluvie.json': 'ac338d89644cd5f6',
  'audio_tracks.fluvie.json': 'e56cc37550dd16ab',
  'clip_speed.fluvie.json': '5971910c209f43c8',
  'clip_speed_ramp.fluvie.json': 'dd20ab0c7cffe547',
  'clip_transitions.fluvie.json': 'e77c84755aacca83',
  'effects.fluvie.json': '50fa846efb7815dc',
  'gradient_stops.fluvie.json': '67db0a0d51e98b11',
  'groups.fluvie.json': '4b61a0e170ad45a7',
  'lanes.fluvie.json': '4abc4a3e598b8ec9',
  'masters.fluvie.json': '1b51d85c21fb6102',
  'maximal.fluvie.json': '19be8def7d4bf31b',
  'minimal.fluvie.json': '797f327c3b86cd81',
  'overlays.fluvie.json': '5170891eb11311b0',
  'positioned.fluvie.json': 'a34cd836e5b226e1',
  'preset_sweep.fluvie.json': '2096a19f432bba03',
  'rich.fluvie.json': 'e66da855fc4c108c',
  'shared_hero.fluvie.json': '90847e53df156ab1',
  'show_windows.fluvie.json': 'ed72cad8eafde46c',
  'split_text.fluvie.json': '417c3f8b088aee77',
  'steps_notes.fluvie.json': '30f9f9f8bda3a360',
  'themed.fluvie.json': 'c08cc3d6912d19f2',
  'wave2_media.fluvie.json': 'f19960ce5a0d811c',
  'wave2_presets.fluvie.json': '22c6f00964748cf2',
  'wave2_surfaces.fluvie.json': 'd6521f969127e33e',
  'wave2_text.fluvie.json': 'cfea1c572721c332',
  'wave2_wrappers.fluvie.json': '113b8b51ce97b2ab',
};

List<File> _fixtures() =>
    Directory(
        'test/serialization/corpus',
      ).listSync().whereType<File>().where((file) => file.path.endsWith('.fluvie.json')).toList()
      ..sort((a, b) => a.path.compareTo(b.path));

void main() {
  test('every corpus fixture digests to its pinned value', () {
    final moved = <String>[];
    for (final file in _fixtures()) {
      final name = file.uri.pathSegments.last;
      final pinned = _corpusDigests[name];
      if (pinned == null) continue; // the coverage test below names it.
      final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      final actual = VideoSpec.fromJson(json).digest();
      if (actual != pinned) moved.add('$name: pinned $pinned, got $actual');
    }
    expect(
      moved,
      isEmpty,
      reason:
          'A document that used to render one way now canonicalizes differently. '
          'Decide which happened before touching the table: an unintended change '
          'reached the spec surface (fix the code), or a deliberate format change '
          'landed (update the value in the same commit).\n${moved.join('\n')}',
    );
  });

  test('the pin table covers every fixture and names no missing one', () {
    final onDisk = {for (final file in _fixtures()) file.uri.pathSegments.last};
    expect(
      onDisk.difference(_corpusDigests.keys.toSet()),
      isEmpty,
      reason: 'A new corpus fixture needs its digest pinned in this table.',
    );
    expect(
      _corpusDigests.keys.toSet().difference(onDisk),
      isEmpty,
      reason: 'The table pins a fixture that no longer exists; drop the entry.',
    );
  });
}
