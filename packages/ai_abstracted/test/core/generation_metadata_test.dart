import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:test/test.dart';

void main() {
  group('GenerationMetadata', () {
    test('defaults', () {
      const metadata = GenerationMetadata(model: 'm');
      expect(metadata.model, 'm');
      expect(metadata.durationMs, isNull);
      expect(metadata.hasAudio, isFalse);
      expect(metadata.width, isNull);
      expect(metadata.height, isNull);
      expect(metadata.providerJobId, isNull);
      expect(metadata.extra, isEmpty);
    });

    test('duration getter derives from durationMs', () {
      expect(const GenerationMetadata(model: 'm').duration, isNull);
      expect(
        const GenerationMetadata(model: 'm', durationMs: 1500).duration,
        const Duration(milliseconds: 1500),
      );
    });

    test('carries width, height, audio, job id and extra', () {
      const metadata = GenerationMetadata(
        model: 'veo-3.0',
        durationMs: 8000,
        hasAudio: true,
        width: 1920,
        height: 1080,
        providerJobId: 'job-1',
        extra: {'fps': 24},
      );
      expect(metadata.hasAudio, isTrue);
      expect(metadata.width, 1920);
      expect(metadata.height, 1080);
      expect(metadata.providerJobId, 'job-1');
      expect(metadata.extra['fps'], 24);
    });
  });
}
