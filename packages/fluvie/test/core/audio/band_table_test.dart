import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/audio/band_table.dart';
import 'package:fluvie/src/core/audio_band.dart';

BandTable _table() => BandTable({
  AudioBand.bass: Float64List.fromList([0.0, 0.5, 1.0, 0.25]),
  AudioBand.mid: Float64List.fromList([0.1, 0.2, 0.3, 0.4]),
  AudioBand.treble: Float64List.fromList([0.9, 0.8, 0.7, 0.6]),
});

void main() {
  group('BandTable.toString', () {
    test('names the total frames and the bands present', () {
      final s = _table().toString();
      expect(s, contains('totalFrames: 4'));
      expect(s, contains('bass'));
    });
  });

  group('BandTable.energyAt', () {
    test('returns the stored energy at an in-range frame', () {
      final table = _table();
      expect(table.energyAt(1, AudioBand.bass), 0.5);
      expect(table.energyAt(2, AudioBand.bass), 1.0);
      expect(table.energyAt(0, AudioBand.treble), 0.9);
    });

    test('clamps a negative frame to the first sample', () {
      expect(_table().energyAt(-5, AudioBand.bass), 0.0);
    });

    test('clamps a past-the-end frame to the last sample', () {
      expect(_table().energyAt(99, AudioBand.bass), 0.25);
    });
  });

  group('BandTable shape', () {
    test('totalFrames is the per-band length', () {
      expect(_table().totalFrames, 4);
    });

    test('every band has the same length as totalFrames', () {
      final table = _table();
      for (final band in AudioBand.values) {
        expect(table.energiesFor(band).length, table.totalFrames);
      }
    });

    test('a band with no data reads zero', () {
      final table = BandTable({
        AudioBand.bass: Float64List.fromList([0.5, 0.5]),
      });
      expect(table.energyAt(0, AudioBand.mid), 0.0);
    });
  });

  group('BandTable value equality', () {
    test('two tables with identical contents are equal', () {
      expect(_table(), _table());
      expect(_table().hashCode, _table().hashCode);
    });

    test('differing energies are unequal', () {
      final other = BandTable({
        AudioBand.bass: Float64List.fromList([0.0, 0.5, 1.0, 0.99]),
        AudioBand.mid: Float64List.fromList([0.1, 0.2, 0.3, 0.4]),
        AudioBand.treble: Float64List.fromList([0.9, 0.8, 0.7, 0.6]),
      });
      expect(_table(), isNot(other));
    });
  });

  group('BandTable JSON round-trip', () {
    test('toJson/fromJson preserves the energies', () {
      final restored = BandTable.fromJson(_table().toJson());
      expect(restored, _table());
    });

    test('the encoded JSON is byte-stable across two encodes', () {
      expect(_table().toJsonString(), _table().toJsonString());
    });

    test('an empty table round-trips', () {
      final empty = BandTable(const {});
      expect(BandTable.fromJson(empty.toJson()), empty);
      expect(empty.totalFrames, 0);
    });
  });

  group('BandTable.fromHops resamples hop energies to per-frame', () {
    test('maps a per-hop band sum onto a totalFrames-long table', () {
      // ~86 hops/s at 1024/512 over 44100, so 6 frames at 30 fps (0.2 s) span
      // about 17 hops. Put the bass peak halfway through (hop 9, ~0.1 s -> frame
      // 3) and assert that frame is the strongest.
      final bass = Float64List(20);
      bass[9] = 1.0;
      final hops = {
        AudioBand.bass: bass,
        AudioBand.mid: Float64List(20),
        AudioBand.treble: Float64List(20),
      };
      final table = BandTable.fromHops(
        hops,
        hopSize: 512,
        sampleRate: 44100,
        fps: 30,
        totalFrames: 6,
      );
      expect(table.totalFrames, 6);
      final peakFrame = _argMax(table.energiesFor(AudioBand.bass));
      expect(peakFrame, inInclusiveRange(2, 4));
      expect(table.energyAt(peakFrame, AudioBand.bass), greaterThan(0));
      // Peak-normalized: the strongest frame is exactly 1.0.
      expect(table.energyAt(peakFrame, AudioBand.bass), closeTo(1.0, 1e-9));
    });

    test('is deterministic', () {
      final hops = {
        AudioBand.bass: Float64List.fromList([0.2, 0.4, 0.6, 0.8]),
        AudioBand.mid: Float64List.fromList([0.1, 0.1, 0.1, 0.1]),
        AudioBand.treble: Float64List.fromList([0.3, 0.3, 0.3, 0.3]),
      };
      BandTable build() => BandTable.fromHops(
        hops,
        hopSize: 512,
        sampleRate: 44100,
        fps: 30,
        totalFrames: 12,
      );
      expect(build(), build());
    });
  });
}

int _argMax(Float64List values) {
  var best = 0;
  for (var i = 1; i < values.length; i++) {
    if (values[i] > values[best]) best = i;
  }
  return best;
}
