// The waveform envelope: a pure time-domain reduction of decoded PCM into
// evenly spaced buckets an editor can draw. Deliberately not built on
// BandTable, which peak-normalises each frequency band against that band's own
// maximum and so is not proportional to signal level.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/audio/waveform_envelope.dart';

/// [count] samples of a full-scale sine at [cycles] cycles across the buffer.
Float64List _sine(int count, {int cycles = 4}) => Float64List.fromList([
  for (var i = 0; i < count; i++) math.sin(2 * math.pi * cycles * i / count),
]);

void main() {
  group('bucket geometry', () {
    test('reduces to exactly the requested bucket count', () {
      final envelope = reduceToWaveform(
        (samples: _sine(1000), sampleRate: 48000),
        buckets: 64,
      );

      expect(envelope.buckets, hasLength(64));
      expect(envelope.sampleRate, 48000);
    });

    test('fewer samples than buckets still fills every bucket', () {
      // An editor asks for one bucket per pixel; a very short clip must not
      // leave holes in the drawing.
      final envelope = reduceToWaveform(
        (samples: Float64List.fromList(const [1, -1, 0.5]), sampleRate: 8000),
        buckets: 10,
      );

      expect(envelope.buckets, hasLength(10));
      for (final bucket in envelope.buckets) {
        expect(bucket.max, greaterThanOrEqualTo(bucket.min));
      }
    });

    test('a bucket count below one is refused rather than silently clamped', () {
      expect(
        () => reduceToWaveform((samples: _sine(100), sampleRate: 8000), buckets: 0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('empty audio reduces to an empty envelope, not to a throw', () {
      final envelope = reduceToWaveform(
        (samples: Float64List(0), sampleRate: 48000),
        buckets: 32,
      );

      expect(envelope.buckets, isEmpty);
      expect(envelope.durationSeconds, 0);
    });
  });

  group('what a bucket reports', () {
    test('digital silence reads as zero everywhere', () {
      final envelope = reduceToWaveform(
        (samples: Float64List(512), sampleRate: 48000),
        buckets: 16,
      );

      for (final bucket in envelope.buckets) {
        expect(bucket.min, 0);
        expect(bucket.max, 0);
        expect(bucket.rms, 0);
      }
    });

    test('a full-scale square reads as full scale, and rms is not the peak', () {
      final square = Float64List.fromList([
        for (var i = 0; i < 400; i++)
          if (i.isEven) 1.0 else -1.0,
      ]);

      final bucket = reduceToWaveform((
        samples: square,
        sampleRate: 48000,
      ), buckets: 1).buckets.single;

      expect(bucket.min, -1);
      expect(bucket.max, 1);
      expect(bucket.rms, closeTo(1, 1e-12), reason: 'a square sits at full scale');
    });

    test('a sine reports its peaks and an rms well below them', () {
      final bucket = reduceToWaveform(
        (samples: _sine(4096, cycles: 8), sampleRate: 48000),
        buckets: 1,
      ).buckets.single;

      expect(bucket.max, closeTo(1, 0.01));
      expect(bucket.min, closeTo(-1, 0.01));
      // A sine's rms is 1/sqrt(2) of its peak; that separation is the whole
      // reason a bucket carries both.
      expect(bucket.rms, closeTo(1 / math.sqrt2, 0.01));
    });

    test('the duration comes from the sample rate, not the bucket count', () {
      final envelope = reduceToWaveform(
        (samples: Float64List(48000), sampleRate: 48000),
        buckets: 7,
      );

      expect(envelope.durationSeconds, closeTo(1, 1e-12));
    });
  });

  group('stability across zoom levels', () {
    test('doubling the bucket count preserves every peak', () {
      // An editor redraws the same waveform at many widths. If a peak vanished
      // when the user zoomed, the drawing would lie about the audio.
      final audio = (samples: _sine(9973, cycles: 37), sampleRate: 44100);
      final coarse = reduceToWaveform(audio, buckets: 200);
      final fine = reduceToWaveform(audio, buckets: 400);

      for (var i = 0; i < coarse.buckets.length; i++) {
        final pair = [fine.buckets[i * 2], fine.buckets[i * 2 + 1]];
        expect(
          coarse.buckets[i].max,
          closeTo(pair.map((b) => b.max).reduce(math.max), 1e-12),
          reason: 'bucket $i lost its peak between zoom levels',
        );
        expect(
          coarse.buckets[i].min,
          closeTo(pair.map((b) => b.min).reduce(math.min), 1e-12),
        );
      }
    });

    test('the same audio always reduces identically', () {
      final audio = (samples: _sine(2048), sampleRate: 48000);

      final first = reduceToWaveform(audio, buckets: 128);
      final second = reduceToWaveform(audio, buckets: 128);

      expect(
        first.buckets.map((b) => b.max),
        second.buckets.map((b) => b.max),
      );
    });
  });

  test('peak is the larger absolute extreme, whichever side it is on', () {
    final skewed = Float64List.fromList(const [0.2, -0.9, 0.3]);

    final bucket = reduceToWaveform(
      (samples: skewed, sampleRate: 8000),
      buckets: 1,
    ).buckets.single;

    expect(bucket.peak, closeTo(0.9, 1e-12));
  });
}
