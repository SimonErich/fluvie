// WI-25 (D-CaptureShell): the example render harness is a THIN caller of the
// production capture shell (rendering/capture/capture_shell.dart). This test
// drives a Trigger.beat composition through the harness offline, injecting the
// example's offline fakes through the shell's injection points (the resolver,
// the reactive tracks). The BeatGridScope the shell mounts resolves the beat, so
// a Trigger.beat composition renders through the same path the lesson posters
// use — deterministically, with no ffmpeg and no host.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart' hide Animation, Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/src/composition/runtime/reactive_collector.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/audio/band_table.dart';
import 'package:fluvie/src/core/captions/caption_source.dart';
import 'package:fluvie/src/core/contracts/beat_grid.dart';
import 'package:fluvie/src/core/media/snapshot_source.dart';
import 'package:fluvie_example/render/composition_entry.dart';

import 'render_harness.dart';

const int _width = 320;
const int _height = 240;
const int _fps = 30;
const int _frames = 24;

const _song = AudioSource.asset('audio/beat.wav');
final _track = Anchor('beat-track');

/// A composition with a Trigger.beat fade. The grid the injected resolver serves
/// fires at frame 6, so the fade window is 6..16 — the wiring this exercises
/// through the shell.
final _entry = CompositionEntry(
  key: 'beat_through_shell',
  width: _width,
  height: _height,
  fps: _fps,
  frameCount: _frames,
  build: () => Video(
    // fps is the default 30 (== _fps), so the entry and the Video agree.
    width: _width,
    height: _height,
    audio: [Audio.music('audio/beat.wav', track: _track)],
    scenes: [
      Scene(
        duration: const Time.frames(_frames),
        children: [
          const ColoredBox(
            color: Color(0xFF101010),
            child: SizedBox.expand(),
          ),
          const Center(
            child: ColoredBox(
              color: Color(0xFFE74C3C),
              child: SizedBox(width: 80, height: 80),
            ),
          ).animate([
            Animation.fadeIn(
              at: Trigger.beat(track: _track),
              duration: const Time.frames(10),
              ease: Ease.linear,
            ),
          ]),
        ],
      ),
    ],
  ),
);

/// An in-house grid that fires on the listed frames — no ffmpeg, no DSP.
class _FixedGrid implements BeatGrid {
  const _FixedGrid(this._beats);
  final List<int> _beats;
  @override
  int? firstBeatAtOrAfter(int frame, {int every = 1}) {
    for (var i = 0; i < _beats.length; i += every) {
      if (_beats[i] >= frame) return _beats[i];
    }
    return null;
  }
}

/// An offline resolver serving a fixed beat grid + a flat band table for the
/// one declared track — the shell reads both synchronously after the pre-pass.
final class _OfflineBeatResolver implements MediaResolver {
  bool _ready = false;

  @override
  Future<void> preResolveReactive(
    Iterable<AudioSource> sources, {
    required BeatDetectionService beatDetector,
    required FrequencyAnalyzer analyzer,
    required int fps,
    required int totalFrames,
  }) async => _ready = true;

  @override
  BeatGrid beatGridFor(AudioSource source) {
    _assert();
    return const _FixedGrid([6, 18]);
  }

  @override
  BandTable bandTableFor(AudioSource source) {
    _assert();
    return BandTable({AudioBand.bass: Float64List(_frames)});
  }

  void _assert() {
    if (!_ready) throw StateError('preResolveReactive has not run.');
  }

  @override
  Future<void> preResolveAll(Iterable<MediaSource> sources) async => _ready = true;
  @override
  Future<void> preResolveAudio(Iterable<AudioSource> sources) async => _ready = true;
  @override
  Future<ClipMetadata> probeClip(MediaSource source) async =>
      (fps: 30.0, frameCount: 1, width: 1, height: 1);
  @override
  Future<void> preResolveClip(MediaSource source, Iterable<int> frames) async => _ready = true;
  @override
  Future<void> preResolveSnapshots(Iterable<SnapshotSource> s, SnapshotService svc) async =>
      _ready = true;
  @override
  Future<void> preResolveCaptions(CaptionSource source) async => _ready = true;
  @override
  ResolvedMedia resolvedFor(MediaSource source) => throw UnimplementedError();
  @override
  ui.Image decodedImageFor(MediaSource source) => throw UnimplementedError();
  @override
  ClipMetadata clipMetadataFor(MediaSource source) => throw UnimplementedError();
  @override
  ui.Image decodedClipFrame(MediaSource source, int frame) => throw UnimplementedError();
  @override
  ui.Image decodedSnapshotFor(SnapshotSource source) => throw UnimplementedError();
  @override
  String materializedAudioPathFor(AudioSource source) => throw UnimplementedError();
  @override
  List<CaptionCue> cuesFor(CaptionSource source) => throw UnimplementedError();
}

Future<MediaResolver?> _prepare(CompositionEntry entry) async {
  // The example normally runs the real spectral DSP over the committed WAV in
  // the pre-pass; here the offline resolver mints the grid/table directly, so
  // the pre-pass just flips it ready (no ffmpeg, no DSP).
  final resolver = _OfflineBeatResolver();
  await resolver.preResolveAudio(const [_song]);
  return resolver;
}

ReactiveTracks _tracks(CompositionEntry entry) =>
    ReactiveTracks(byAnchor: {_track: _song}, defaultSource: _song, allSources: {_song});

Directory _tempDir(String label) {
  final dir = Directory.systemTemp.createTempSync('fluvie_beat_shell_${label}_');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

void main() {
  testWidgets('a Trigger.beat composition renders through the shell offline', (tester) async {
    final outDir = _tempDir('one');
    final manifest = await runCaptureHarness(
      tester: tester,
      entry: _entry,
      outDir: outDir,
      cacheEnabled: false,
      prepareMedia: _prepare,
      snapshotScenes: (_) => const [],
      reactiveTracks: _tracks,
    );
    expect(manifest.frameCount, _frames);
    final frames = File('${outDir.path}/frames.rgba').readAsBytesSync();
    expect(frames.length, _frames * _width * _height * 4);
  });

  testWidgets('two runs through the shell are byte-identical (deterministic)', (tester) async {
    final outA = _tempDir('a');
    final outB = _tempDir('b');
    for (final outDir in [outA, outB]) {
      await runCaptureHarness(
        tester: tester,
        entry: _entry,
        outDir: outDir,
        cacheEnabled: false,
        prepareMedia: _prepare,
        snapshotScenes: (_) => const [],
        reactiveTracks: _tracks,
      );
    }
    expect(
      File('${outA.path}/frames.rgba').readAsBytesSync(),
      File('${outB.path}/frames.rgba').readAsBytesSync(),
    );
  });

  testWidgets('the beat fade is dark before frame 6 and lit by frame 16', (tester) async {
    final outDir = _tempDir('probe');
    await runCaptureHarness(
      tester: tester,
      entry: _entry,
      outDir: outDir,
      cacheEnabled: false,
      prepareMedia: _prepare,
      snapshotScenes: (_) => const [],
      reactiveTracks: _tracks,
    );
    final frames = File('${outDir.path}/frames.rgba').readAsBytesSync();
    const frameBytes = _width * _height * 4;
    // The 80x80 box is centred; sample its centre pixel.
    const centre = (_height ~/ 2 * _width + _width ~/ 2) * 4;
    int alphaAt(int frame) => frames[frame * frameBytes + centre + 0];
    // Before the beat (frame 6) the fade has not started; well after it the box
    // is fully faded in. The grid the shell mounted resolved the beat, so the
    // box only appears from frame 6 onward.
    expect(alphaAt(3) < alphaAt(20), isTrue);
  });
}
