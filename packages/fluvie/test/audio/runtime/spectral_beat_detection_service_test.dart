import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/audio/runtime/pcm_decoder.dart';
import 'package:fluvie/src/audio/runtime/spectral_beat_detection_service.dart';
import 'package:fluvie/src/audio/runtime/spectral_frequency_analyzer.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/audio/band_table.dart';
import 'package:fluvie/src/core/audio/dsp/wav_reader.dart';
import 'package:fluvie/src/core/audio_band.dart';
import 'package:fluvie/src/core/contracts/beat_grid.dart';

final _fixturePath = '${Directory.current.path}/test/core/audio/fixtures/sine_441_stereo.wav';

/// A [PcmDecoder] that ignores the source and returns committed [pcm] — the
/// gate default, so no ffmpeg is spawned. [decodeCount] counts real decodes so
/// the cache-hit test can prove a second call skips it.
class _FixtureDecoder implements PcmDecoder {
  _FixtureDecoder(this.pcm);

  final PcmAudio pcm;
  int decodeCount = 0;

  @override
  Future<PcmAudio> decode(AudioSource source) async {
    decodeCount++;
    return pcm;
  }
}

/// A click-track PCM: broadband bursts at known seconds so detection finds beats
/// (the committed sine fixture is a steady tone with no onsets).
PcmAudio _clickPcm() {
  const sampleRate = 44100;
  final samples = Float64List(sampleRate * 2);
  for (final second in [0.5, 1.0, 1.5]) {
    final start = (second * sampleRate).round();
    var seed = 1;
    for (var i = 0; i < (0.012 * sampleRate).round(); i++) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      samples[start + i] = (seed / 0x7fffffff * 2 - 1) * (1 - i / (0.012 * sampleRate));
    }
  }
  return (samples: samples, sampleRate: sampleRate);
}

void main() {
  group('SpectralBeatDetectionService.detect', () {
    test('returns a BeatGrid with beats near the click positions', () async {
      final decoder = _FixtureDecoder(_clickPcm());
      final service = SpectralBeatDetectionService(decoder: decoder);
      final grid = await service.detect(
        const AudioSource.asset('beat.wav'),
        fps: 30,
        totalFrames: 60,
      );
      expect(grid, isA<BeatGrid>());
      // A beat near 0.5 s -> frame 15.
      final first = grid.firstBeatAtOrAfter(0);
      expect(first, isNotNull);
      expect((first! - 15).abs(), lessThanOrEqualTo(2));
    });

    test('detecting twice for real yields an identical grid', () async {
      // Two separate services, each with its own decoder, so neither call is a
      // cache hit: the DSP runs twice for real and must agree.
      const source = AudioSource.asset('beat.wav');
      final first = SpectralBeatDetectionService(decoder: _FixtureDecoder(_clickPcm()));
      final second = SpectralBeatDetectionService(decoder: _FixtureDecoder(_clickPcm()));
      final a = await first.detect(source, fps: 30, totalFrames: 60);
      final b = await second.detect(source, fps: 30, totalFrames: 60);
      // Same beats, queried across the whole range.
      final beatsA = _allBeats(a, 60);
      final beatsB = _allBeats(b, 60);
      expect(beatsA, isNotEmpty);
      expect(beatsA, orderedEquals(beatsB));
    });

    test('a cache hit skips the decode', () async {
      final decoder = _FixtureDecoder(_clickPcm());
      final service = SpectralBeatDetectionService(decoder: decoder);
      const source = AudioSource.asset('beat.wav');
      await service.detect(source, fps: 30, totalFrames: 60);
      await service.detect(source, fps: 30, totalFrames: 60);
      expect(decoder.decodeCount, 1);
    });

    test('reads the committed WAV fixture through the decoder', () async {
      final pcm = readPcmWav(File(_fixturePath).readAsBytesSync());
      final service = SpectralBeatDetectionService(decoder: _FixtureDecoder(pcm));
      // The steady sine has no onsets, so the grid is empty — still a valid grid.
      final grid = await service.detect(
        const AudioSource.asset('sine.wav'),
        fps: 30,
        totalFrames: 10,
      );
      expect(grid.firstBeatAtOrAfter(0), isNull);
    });
  });

  group('SpectralFrequencyAnalyzer.analyze', () {
    test('returns a BandTable spanning totalFrames', () async {
      final analyzer = SpectralFrequencyAnalyzer(decoder: _FixtureDecoder(_clickPcm()));
      final table = await analyzer.analyze(
        const AudioSource.asset('beat.wav'),
        fps: 30,
        totalFrames: 60,
      );
      expect(table, isA<BandTable>());
      expect(table.totalFrames, 60);
    });

    test('the click track carries band energy somewhere', () async {
      final analyzer = SpectralFrequencyAnalyzer(decoder: _FixtureDecoder(_clickPcm()));
      final table = await analyzer.analyze(
        const AudioSource.asset('beat.wav'),
        fps: 30,
        totalFrames: 60,
      );
      var maxEnergy = 0.0;
      for (var frame = 0; frame < 60; frame++) {
        for (final band in AudioBand.values) {
          if (table.energyAt(frame, band) > maxEnergy) {
            maxEnergy = table.energyAt(frame, band);
          }
        }
      }
      expect(maxEnergy, greaterThan(0));
    });

    test('analysing twice for real yields an identical table', () async {
      // Two separate analyzers, each with its own decoder, so neither call is a
      // cache hit: the DSP runs twice for real and the two tables must be equal
      // by value (and by their byte-stable JSON).
      const source = AudioSource.asset('beat.wav');
      final first = SpectralFrequencyAnalyzer(decoder: _FixtureDecoder(_clickPcm()));
      final second = SpectralFrequencyAnalyzer(decoder: _FixtureDecoder(_clickPcm()));
      final a = await first.analyze(source, fps: 30, totalFrames: 60);
      final b = await second.analyze(source, fps: 30, totalFrames: 60);
      expect(a, b);
      expect(a.toJsonString(), b.toJsonString());
    });

    test('a cache hit skips the decode', () async {
      final decoder = _FixtureDecoder(_clickPcm());
      final analyzer = SpectralFrequencyAnalyzer(decoder: decoder);
      const source = AudioSource.asset('beat.wav');
      await analyzer.analyze(source, fps: 30, totalFrames: 60);
      await analyzer.analyze(source, fps: 30, totalFrames: 60);
      expect(decoder.decodeCount, 1);
    });
  });
}

List<int> _allBeats(BeatGrid grid, int totalFrames) {
  final beats = <int>[];
  var cursor = 0;
  while (cursor < totalFrames) {
    final next = grid.firstBeatAtOrAfter(cursor);
    if (next == null) break;
    beats.add(next);
    cursor = next + 1;
  }
  return beats;
}
