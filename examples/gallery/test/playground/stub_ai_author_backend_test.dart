import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_example/playground/stub_ai_author_backend.dart';

void main() {
  final stub = StubAiAuthorBackend(latency: Duration.zero);

  test('generates a Video build() with the prompt as the headline', () async {
    final result = await stub.author('Big launch day');
    expect(result.code, contains('Video build()'));
    expect(result.code, contains("'Big launch day'"));
    expect(result.code, contains('Background.gradient'));
  });

  test('picks a red gradient when the prompt mentions red', () async {
    final result = await stub.author('a red sale banner');
    expect(result.code, contains('0xFFE53935'));
  });

  test('escapes single quotes so the headline stays a valid string', () async {
    final result = await stub.author("it's here");
    expect(result.code, contains(r"it\'s here"));
  });

  test('an edit preserves the existing headline and applies the new colour', () async {
    final first = await stub.author('Welcome aboard');
    final edited = await stub.author('make it green', currentCode: first.code);
    expect(edited.code, contains("'Welcome aboard'"), reason: 'the headline is kept');
    expect(edited.code, contains('0xFF11998E'), reason: 'the new colour is applied');
  });

  test('caps a very long prompt with an ellipsis', () async {
    final result = await stub.author('word ' * 50);
    expect(result.code, contains('...'));
  });
}
