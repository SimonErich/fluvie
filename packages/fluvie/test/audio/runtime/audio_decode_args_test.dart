import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/audio/runtime/audio_decode_args.dart';

void main() {
  group('audioDecodeArgs', () {
    test('emits the order-stable f32le mono 44100 pipe-to-stdout array', () {
      expect(audioDecodeArgs('track0.wav'), const [
        '-i',
        'track0.wav',
        '-f',
        'f32le',
        '-ac',
        '1',
        '-ar',
        '44100',
        '-',
      ]);
    });

    test('is deterministic across calls', () {
      expect(audioDecodeArgs('a.mp3'), audioDecodeArgs('a.mp3'));
    });

    test('validates the name: rejects path traversal', () {
      expect(() => audioDecodeArgs('../evil.wav'), throwsArgumentError);
    });

    test('validates the name: rejects a flag-shaped name', () {
      expect(() => audioDecodeArgs('-evil.wav'), throwsArgumentError);
    });

    test('validates the name: rejects an empty name', () {
      expect(() => audioDecodeArgs(''), throwsArgumentError);
    });

    test('the input name is the second argument, the sink is last', () {
      final args = audioDecodeArgs('song.mp3');
      expect(args[1], 'song.mp3');
      expect(args.last, '-');
    });
  });
}
