// AUDMIX-WIRE (Phase-14 fix): the production capture path must STAGE the audio
// mix, not emit a silent video. This drives an Audio-bearing composition through
// the real capture harness offline (the committed WAV materializes with a plain
// byte copy — no ffmpeg) and asserts the manifest's ffmpegArgs carry the mix
// (`-filter_complex` + the `[aout]` map label, never `-an`), and that an
// `Audio.sfx(at:)` lands an `adelay` in those args. Mirrors harness_shell_test:
// a thin caller of the production shell over the composition's own declarations.
//
// `renderVideo` derives the mix from the Video, so nothing is injected here: the
// entries below declare their `Audio` and the render stages it, which is exactly
// what the fix has to guarantee for a real lesson.

import 'dart:io';

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie_example/render/composition_entry.dart';

import 'render_harness.dart';

const int _width = 160;
const int _height = 120;
const int _fps = 30;
const int _frames = 30;

/// The committed WAV (lesson 12's music bed) — materializes with a byte copy.
const String _wav = 'assets/audio/beat_loop.wav';

/// A music-bearing composition: one `Audio.music` over the committed WAV.
final CompositionEntry _musicEntry = _entry(
  key: 'audio_mix_music',
  audio: const [Audio.music(_wav)],
);

/// An sfx-bearing composition firing one pop at the 1 second mark.
final CompositionEntry _sfxEntry = _entry(
  key: 'audio_mix_sfx',
  audio: [Audio.sfx(_wav, at: Trigger.at(1.seconds))],
);

/// A music bed with a fade-out: the ramp must land at the END of the window,
/// not at st=0 (which would mute the whole bed — the silent-render bug).
final CompositionEntry _fadeEntry = _entry(
  key: 'audio_mix_fade',
  audio: const [Audio.music(_wav, fadeOut: Time.frames(15))],
);

/// A silent composition: no audio, no media — the encoder's `-an` path.
final CompositionEntry _silentEntry = _entry(key: 'audio_mix_silent', audio: const []);

/// Builds a [key]ed entry over a [_width]x[_height], [_frames]-frame Video
/// declaring [audio]. The fps is the `Video` default (30, == [_fps]), which the
/// sfx `adelay` and the fade `st=` below are computed against.
CompositionEntry _entry({required String key, required List<Audio> audio}) => CompositionEntry(
  key: key,
  video: () => Video(
    width: _width,
    height: _height,
    audio: audio,
    scenes: const [
      Scene(
        duration: Time.frames(_frames),
        children: [ColoredBox(color: Color(0xFF101010), child: SizedBox.expand())],
      ),
    ],
  ),
);

Directory _tempDir(String label) {
  final dir = Directory.systemTemp.createTempSync('fluvie_audio_mix_${label}_');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

/// Renders [entry] through the default harness wiring: `prepareEntryMedia` mints
/// a real, offline `MediaRepository` over the asset bundle for an entry that
/// declares audio (a plain bundle read plus a byte copy, so no ffmpeg), and
/// `null` for the silent one — which is the `-an` path under test.
Future<RenderManifest> _render(WidgetTester tester, CompositionEntry entry, String label) async {
  return runCaptureHarness(
    tester: tester,
    entry: entry,
    outDir: _tempDir(label),
    cacheEnabled: false,
  );
}

void main() {
  testWidgets('a music composition stages the mix into the manifest (not -an)', (tester) async {
    final manifest = await _render(tester, _musicEntry, 'music');
    expect(manifest.ffmpegArgs, contains('-filter_complex'));
    expect(manifest.ffmpegArgs, containsAllInOrder(<String>['-map', '[aout]']));
    expect(manifest.ffmpegArgs, isNot(contains('-an')));
  });

  testWidgets('an Audio.sfx(at: 1s) lands an adelay in the mix args', (tester) async {
    final manifest = await _render(tester, _sfxEntry, 'sfx');
    final graph = _filterComplex(manifest.ffmpegArgs);
    expect(graph, contains('adelay=1000|1000'));
  });

  testWidgets('a music fade-out is end-anchored, never st=0 (the silent bug)', (tester) async {
    // 30 frames @ 30 fps = a 1 s window; a 15-frame (0.5 s) fade-out must begin
    // at st=0.5 so the bed plays and only the last half-second ramps down. The
    // render reads both off the Video, so the st= literals below hold only while
    // it declares them.
    expect(_fadeEntry.video().fps, _fps);
    expect(_fadeEntry.video().totalFrames, _frames);
    final manifest = await _render(tester, _fadeEntry, 'fade');
    final graph = _filterComplex(manifest.ffmpegArgs);
    expect(graph, contains('afade=t=out:st=0.5:d=0.5'));
    expect(graph, isNot(contains('afade=t=out:st=0:')));
  });

  testWidgets('a silent composition keeps the -an plan (the demo stays silent)', (tester) async {
    final manifest = await _render(tester, _silentEntry, 'silent');
    expect(manifest.ffmpegArgs, contains('-an'));
    expect(manifest.ffmpegArgs, isNot(contains('-filter_complex')));
  });

  testWidgets('DETERMINISM: the same music composition yields identical args twice', (
    tester,
  ) async {
    final a = await _render(tester, _musicEntry, 'det_a');
    final b = await _render(tester, _musicEntry, 'det_b');
    expect(a.ffmpegArgs, b.ffmpegArgs);
  });
}

/// The `-filter_complex` graph string from [args] (the value after the flag).
String _filterComplex(List<String> args) {
  final index = args.indexOf('-filter_complex');
  expect(index, isNot(-1), reason: 'the mix must route through -filter_complex');
  return args[index + 1];
}
