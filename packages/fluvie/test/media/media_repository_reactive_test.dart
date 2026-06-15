import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/audio/band_table.dart';
import 'package:fluvie/src/core/audio_band.dart';
import 'package:fluvie/src/core/contracts/beat_detection_service.dart';
import 'package:fluvie/src/core/contracts/beat_grid.dart';
import 'package:fluvie/src/core/contracts/frequency_analyzer.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/media/media_bytes_loader.dart';
import 'package:fluvie/src/media/media_repository.dart';
import 'package:fluvie/src/media/net/media_http_client.dart';
import 'package:fluvie/src/media/net/network_allowlist.dart';

class _MapBundle extends CachingAssetBundle {
  _MapBundle(this._data);
  final Map<String, Uint8List> _data;
  @override
  Future<ByteData> load(String key) async {
    final bytes = _data[key];
    if (bytes == null) throw FluvieRenderException('asset not found: $key');
    return ByteData.view(bytes.buffer);
  }
}

class _NoHttp implements MediaHttpClient {
  const _NoHttp();
  @override
  Future<Uint8List> get(Uri url) async => throw StateError('no network');
}

class _StubBeatGrid implements BeatGrid {
  @override
  int? firstBeatAtOrAfter(int frame, {int every = 1}) => frame <= 10 ? 10 : null;
}

class _CountingBeatService implements BeatDetectionService {
  int calls = 0;
  @override
  Future<BeatGrid> detect(AudioSource source, {required int fps, required int totalFrames}) async {
    calls++;
    return _StubBeatGrid();
  }
}

class _CountingAnalyzer implements FrequencyAnalyzer {
  int calls = 0;
  @override
  Future<BandTable> analyze(
    AudioSource source, {
    required int fps,
    required int totalFrames,
  }) async {
    calls++;
    return BandTable({
      AudioBand.bass: Float64List.fromList(List<double>.filled(totalFrames, 0.5)),
    });
  }
}

MediaRepository _repo(Map<String, Uint8List> assets) => MediaRepository(
  loader: MediaBytesLoader(
    bundle: _MapBundle(assets),
    httpClient: const _NoHttp(),
    allowlist: NetworkAllowlist.allowAny(),
  ),
);

void main() {
  final pcm = Uint8List.fromList(List.generate(64, (i) => i % 256));

  group('MediaRepository.preResolveReactive', () {
    test('analyses each source into a beat grid and a band table', () async {
      final repo = _repo({'beat.wav': pcm});
      const source = AudioSource.asset('beat.wav');
      final beats = _CountingBeatService();
      final analyzer = _CountingAnalyzer();

      await repo.preResolveReactive(
        const [source],
        beatDetector: beats,
        analyzer: analyzer,
        fps: 30,
        totalFrames: 20,
      );

      expect(repo.beatGridFor(source).firstBeatAtOrAfter(0), 10);
      expect(repo.bandTableFor(source).energyAt(0, AudioBand.bass), 0.5);
      expect(repo.bandTableFor(source).totalFrames, 20);
    });

    test('is idempotent: a repeated reactive pre-resolve runs analysis once', () async {
      final repo = _repo({'beat.wav': pcm});
      const source = AudioSource.asset('beat.wav');
      final beats = _CountingBeatService();
      final analyzer = _CountingAnalyzer();

      await repo.preResolveReactive(
        const [source],
        beatDetector: beats,
        analyzer: analyzer,
        fps: 30,
        totalFrames: 20,
      );
      await repo.preResolveReactive(
        const [source],
        beatDetector: beats,
        analyzer: analyzer,
        fps: 30,
        totalFrames: 20,
      );

      expect(beats.calls, 1);
      expect(analyzer.calls, 1);
    });

    test('beatGridFor before preResolveReactive throws StateError', () {
      final repo = _repo(const {});
      expect(() => repo.beatGridFor(const AudioSource.asset('x.wav')), throwsStateError);
    });

    test('bandTableFor for an unresolved source throws naming it', () async {
      final repo = _repo({'a.wav': pcm});
      const a = AudioSource.asset('a.wav');
      await repo.preResolveReactive(
        const [a],
        beatDetector: _CountingBeatService(),
        analyzer: _CountingAnalyzer(),
        fps: 30,
        totalFrames: 20,
      );
      expect(
        () => repo.bandTableFor(const AudioSource.asset('other.wav')),
        throwsA(
          isA<FluvieRenderException>().having((e) => e.message, 'message', contains('other.wav')),
        ),
      );
    });
  });
}
