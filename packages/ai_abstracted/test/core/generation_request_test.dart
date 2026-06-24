import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:test/test.dart';

class _StubRequest extends GenerationRequest {
  const _StubRequest({required super.prompt, super.seed, super.model});

  @override
  MediaKind get kind => MediaKind.text;
}

void main() {
  group('GenerationRequest', () {
    test('holds prompt, seed and model', () {
      const request = _StubRequest(prompt: 'hi', seed: '7', model: 'gpt');
      expect(request.prompt, 'hi');
      expect(request.seed, '7');
      expect(request.model, 'gpt');
      expect(request.kind, MediaKind.text);
    });

    test('seed and model default to null', () {
      const request = _StubRequest(prompt: 'hi');
      expect(request.seed, isNull);
      expect(request.model, isNull);
    });
  });
}
