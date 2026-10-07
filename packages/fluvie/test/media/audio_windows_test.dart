import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie/src/audio/runtime/frame_list_beat_grid.dart';
import 'package:fluvie/src/core/audio/band_table.dart';
import 'package:fluvie/src/core/contracts/beat_grid.dart';
import 'package:fluvie/src/media/media_bytes_loader.dart';
import 'package:fluvie/src/media/media_repository.dart';
import 'package:fluvie/src/media/net/media_http_client.dart';

final class _Services implements RangedBeatDetectionService, RangedFrequencyAnalyzer {
  _Services({this.duration = const Duration(milliseconds: 100)});
  final Duration duration;
  final starts = <Duration>[];
  @override
  Future<BeatGrid> detect(AudioSource source, {required int fps, required int totalFrames}) =>
      throw StateError('Unbounded analysis');
  @override
  Future<BandTable> analyze(AudioSource source, {required int fps, required int totalFrames}) =>
      throw StateError('Unbounded analysis');
  @override
  Future<BeatGrid> detectRange(
    AudioSource source, {
    required Duration start,
    required int fps,
    required int totalFrames,
  }) async {
    starts.add(start);
    return FrameListBeatGrid([1]);
  }

  @override
  Future<RangedBandAnalysis> analyzeRange(
    AudioSource source, {
    required Duration start,
    required int fps,
    required int totalFrames,
  }) async => (
    table: BandTable({
      AudioBand.bass: Float64List.fromList([0.25, 1, 0.5]),
    }),
    duration: duration,
  );
}

final class _LegacyServices implements BeatDetectionService, FrequencyAnalyzer {
  final lengths = <int>[];
  @override
  Future<BeatGrid> detect(AudioSource source, {required int fps, required int totalFrames}) async =>
      FrameListBeatGrid([10, 11, 12]);
  @override
  Future<BandTable> analyze(
    AudioSource source, {
    required int fps,
    required int totalFrames,
  }) async {
    lengths.add(totalFrames);
    return BandTable({AudioBand.bass: Float64List.fromList(List.generate(30, (i) => i / 30))});
  }
}

void main() {
  test('trimmed tracks place and repeat analysis on the audible composition clock', () async {
    final source = AudioSource.memory(Uint8List.fromList([1, 2, 3]));
    final services = _Services();
    final repo = MediaRepository(
      loader: MediaBytesLoader(
        httpClient: HttpMediaHttpClient(),
        allowlist: NetworkAllowlist.allowAny(),
      ),
    );
    addTearDown(repo.dispose);
    final single = AudioAnalysisWindow(
      source: source,
      sourceStart: const Duration(seconds: 20),
      sourceFrames: 3,
      startFrame: 2,
      endFrame: 10,
      fps: 30,
    );
    final loop = AudioAnalysisWindow(
      source: source,
      sourceStart: const Duration(seconds: 20),
      sourceFrames: 3,
      startFrame: 2,
      endFrame: 10,
      fps: 30,
      loop: true,
    );
    await repo.preResolveAudioWindows([single, loop], beatDetector: services, analyzer: services);
    expect(services.starts, [const Duration(seconds: 20), const Duration(seconds: 20)]);
    expect(repo.bandTableForWindow(single).energiesFor(AudioBand.bass).take(10), [
      0,
      0,
      .25,
      1,
      .5,
      0,
      0,
      0,
      0,
      0,
    ]);
    expect(repo.bandTableForWindow(loop).energiesFor(AudioBand.bass).take(10), [
      0,
      0,
      .25,
      1,
      .5,
      .25,
      1,
      .5,
      .25,
      1,
    ]);
    expect(repo.bandTableForWindow(loop).energyAt(100, AudioBand.bass), 0);
    expect(repo.beatGridForWindow(single).firstBeatAtOrAfter(4), isNull);
    expect(repo.beatGridForWindow(loop).firstBeatAtOrAfter(4), 6);
    expect(repo.beatGridForWindow(loop).firstBeatAtOrAfter(0, every: 2), 3);
    await repo.preResolveAudioWindows([single], beatDetector: services, analyzer: services);
    expect(services.starts.length, 2);
  });
  test('source EOF preserves a fractional-frame loop period without cumulative drift', () async {
    final source = AudioSource.memory(Uint8List.fromList([1]));
    final services = _Services(duration: const Duration(milliseconds: 80));
    final http = HttpMediaHttpClient();
    addTearDown(http.close);
    final repo = MediaRepository(
      loader: MediaBytesLoader(httpClient: http, allowlist: NetworkAllowlist.allowAny()),
    );
    addTearDown(repo.dispose);
    final window = AudioAnalysisWindow(
      source: source,
      sourceStart: Duration.zero,
      sourceFrames: 3,
      startFrame: 0,
      endFrame: 20,
      fps: 30,
      loop: true,
    );
    await repo.preResolveAudioWindows([window], beatDetector: services, analyzer: services);
    final grid = repo.beatGridForWindow(window) as FrameListBeatGrid;
    expect(grid.beatFrames, [1, 3, 6, 8, 11, 13, 15, 18]);
  });
  test('a custom analyzer must provide a positive duration for a nonempty table', () async {
    final http = HttpMediaHttpClient();
    addTearDown(http.close);
    final repo = MediaRepository(
      loader: MediaBytesLoader(httpClient: http, allowlist: NetworkAllowlist.allowAny()),
    );
    addTearDown(repo.dispose);
    final window = AudioAnalysisWindow(
      source: AudioSource.memory(Uint8List.fromList([1])),
      sourceStart: Duration.zero,
      sourceFrames: 3,
      startFrame: 0,
      endFrame: 10,
      fps: 30,
      loop: true,
    );
    final invalid = _Services(duration: Duration.zero);
    await expectLater(
      repo.preResolveAudioWindows([window], beatDetector: invalid, analyzer: invalid),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('positive duration'),
        ),
      ),
    );
  });
  test('legacy analysis offsets trimmed prefixes and safely handles source EOF', () async {
    final http = HttpMediaHttpClient();
    addTearDown(http.close);
    final repo = MediaRepository(
      loader: MediaBytesLoader(httpClient: http, allowlist: NetworkAllowlist.allowAny()),
    );
    addTearDown(repo.dispose);
    final source = AudioSource.memory(Uint8List.fromList([1]));
    final services = _LegacyServices();
    final windows = [
      for (final seconds in [1, 4])
        AudioAnalysisWindow(
          source: source,
          sourceStart: Duration(seconds: seconds),
          sourceFrames: 3,
          startFrame: 5,
          endFrame: 10,
          fps: 10,
        ),
    ];
    await repo.preResolveAudioWindows(windows, beatDetector: services, analyzer: services);
    expect(services.lengths, [13, 43]);
    final bands = repo.bandTableForWindow(windows.first);
    expect(bands.energyAt(4, AudioBand.bass), 0);
    expect(bands.energyAt(5, AudioBand.bass), closeTo(10 / 30, 1e-9));
    expect(bands.energyAt(7, AudioBand.bass), closeTo(12 / 30, 1e-9));
    expect(bands.energyAt(8, AudioBand.bass), 0);
    expect(repo.beatGridForWindow(windows.first).firstBeatAtOrAfter(0), 5);
    expect(repo.bandTableForWindow(windows.last).energyAt(5, AudioBand.bass), 0);
    expect(repo.beatGridForWindow(windows.last).firstBeatAtOrAfter(0), isNull);
  });
}
