import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/audio/dsp/wav_reader.dart';

/// The committed tiny PCM-WAV fixture: stereo, 44.1 kHz, 256 frames, a 441 Hz
/// sine on the left at full-ish scale and a half-amplitude copy on the right.
final _fixturePath = '${Directory.current.path}/test/core/audio/fixtures/sine_441_stereo.wav';

Uint8List _fixtureBytes() => File(_fixturePath).readAsBytesSync();

/// Builds a minimal PCM-WAV byte buffer in memory for the targeted unit cases
/// (a non-PCM format tag, a single channel, an odd channel count) without
/// committing more fixtures than the one canonical sine.
Uint8List _buildWav({
  required int sampleRate,
  required int channels,
  required int bitsPerSample,
  required List<int> samples, // interleaved signed ints
  int audioFormat = 1, // 1 = PCM
}) {
  final blockAlign = channels * bitsPerSample ~/ 8;
  final dataBytes = samples.length * bitsPerSample ~/ 8;
  final out = BytesBuilder();
  void str(String s) => out.add(s.codeUnits);
  void u32(int v) => out.add((ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List());
  void u16(int v) => out.add((ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List());
  str('RIFF');
  u32(36 + dataBytes);
  str('WAVE');
  str('fmt ');
  u32(16);
  u16(audioFormat);
  u16(channels);
  u32(sampleRate);
  u32(sampleRate * blockAlign);
  u16(blockAlign);
  u16(bitsPerSample);
  str('data');
  u32(dataBytes);
  for (final sample in samples) {
    if (bitsPerSample == 16) {
      out.add((ByteData(2)..setInt16(0, sample, Endian.little)).buffer.asUint8List());
    } else {
      out.add(Uint8List.fromList([sample & 0xff]));
    }
  }
  return out.toBytes();
}

void main() {
  group('readPcmWav sample count and rate', () {
    test('reads 256 mono samples at 44100 Hz from the stereo fixture', () {
      final pcm = readPcmWav(_fixtureBytes());
      expect(pcm.sampleRate, 44100);
      expect(pcm.samples.length, 256);
    });

    test('returns a Float64List of normalized samples', () {
      final pcm = readPcmWav(_fixtureBytes());
      expect(pcm.samples, isA<Float64List>());
      for (final value in pcm.samples) {
        expect(value, inInclusiveRange(-1.0, 1.0));
      }
    });
  });

  group('readPcmWav mono downmix', () {
    test('averages the two channels of an interleaved stereo frame', () {
      // One stereo frame: left = +16384, right = 0 -> average 8192.
      final wav = _buildWav(
        sampleRate: 44100,
        channels: 2,
        bitsPerSample: 16,
        samples: [16384, 0],
      );
      final pcm = readPcmWav(wav);
      expect(pcm.samples.length, 1);
      expect(pcm.samples.first, closeTo(8192 / 32768, 1e-9));
    });

    test('passes a mono file through unchanged', () {
      final wav = _buildWav(
        sampleRate: 22050,
        channels: 1,
        bitsPerSample: 16,
        samples: [32767, -32768, 0],
      );
      final pcm = readPcmWav(wav);
      expect(pcm.sampleRate, 22050);
      expect(pcm.samples.length, 3);
      expect(pcm.samples[0], closeTo(32767 / 32768, 1e-9));
      expect(pcm.samples[1], closeTo(-1.0, 1e-9));
      expect(pcm.samples[2], 0.0);
    });
  });

  group('readPcmWav rejects what it cannot decode', () {
    test('a non-PCM (float) format tag throws a clear error', () {
      final wav = _buildWav(
        sampleRate: 44100,
        channels: 1,
        bitsPerSample: 16,
        samples: [0, 0],
        audioFormat: 3, // IEEE float
      );
      expect(
        () => readPcmWav(wav),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('PCM'),
          ),
        ),
      );
    });

    test('a non-RIFF header throws naming the magic', () {
      final bytes = Uint8List.fromList('NOPEWAVEfmt '.codeUnits);
      expect(
        () => readPcmWav(bytes),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('RIFF'))),
      );
    });

    test('an unsupported bit depth throws naming the depth', () {
      final wav = _buildWav(sampleRate: 44100, channels: 1, bitsPerSample: 8, samples: [0, 0]);
      expect(
        () => readPcmWav(wav),
        throwsA(
          isA<FormatException>().having((e) => e.message, 'message', contains('bit depth 8')),
        ),
      );
    });

    test('a truncated buffer throws instead of reading past the end', () {
      final whole = _buildWav(
        sampleRate: 44100,
        channels: 1,
        bitsPerSample: 16,
        samples: [1, 2, 3, 4],
      );
      final truncated = whole.sublist(0, 30);
      expect(() => readPcmWav(truncated), throwsA(isA<FormatException>()));
    });
  });

  group('readPcmWav determinism', () {
    test('the same bytes decode to identical samples twice', () {
      final bytes = _fixtureBytes();
      final first = readPcmWav(bytes).samples;
      final second = readPcmWav(bytes).samples;
      expect(first, orderedEquals(second));
    });
  });
}
