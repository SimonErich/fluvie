import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:test/test.dart';

void main() {
  group('GenerationStage', () {
    test('has the four locked stages', () {
      expect(GenerationStage.values, [
        GenerationStage.queued,
        GenerationStage.running,
        GenerationStage.downloading,
        GenerationStage.done,
      ]);
    });
  });

  group('GenerationProgress', () {
    test('exposes its fields', () {
      const progress = GenerationProgress(
        stage: GenerationStage.running,
        fraction: 0.5,
        message: 'halfway',
      );
      expect(progress.stage, GenerationStage.running);
      expect(progress.fraction, 0.5);
      expect(progress.message, 'halfway');
    });

    test('value equality and hashCode', () {
      const a = GenerationProgress(stage: GenerationStage.queued, fraction: 0.1);
      const b = GenerationProgress(stage: GenerationStage.queued, fraction: 0.1);
      const c = GenerationProgress(stage: GenerationStage.done);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    test('toString mentions the stage', () {
      expect(
        const GenerationProgress(stage: GenerationStage.downloading).toString(),
        contains('downloading'),
      );
    });
  });
}
