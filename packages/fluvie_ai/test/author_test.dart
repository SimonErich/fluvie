import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_ai/fluvie_ai.dart';
import 'package:riverpod/riverpod.dart';

const _validSpec =
    '{"fluvieSpec":1,"size":"square","fps":30,"scenes":[{"duration":"2s",'
    '"children":[{"type":"Text","text":"Hi","animate":[{"preset":"fadeIn"}]}]}]}';

void main() {
  group('LlmVideoAuthorService', () {
    test('returns a spec when the model emits valid JSON', () async {
      final client = FakeAiClient([_validSpec]);
      final service = LlmVideoAuthorService(client: client);

      final spec = await service.author('a square title card');

      expect(spec.scenes, hasLength(1));
      expect(client.requests, hasLength(1));
      expect(client.requests.first.jsonSchema, isNotNull);
      expect(client.requests.first.messages.first.role, AiRole.system);
    });

    test('strips a markdown code fence the model may add', () async {
      final service = LlmVideoAuthorService(client: FakeAiClient(['```json\n$_validSpec\n```']));
      final spec = await service.author('x');
      expect(spec.scenes, hasLength(1));
    });

    test('repairs invalid JSON, then non-object, then succeeds', () async {
      final client = FakeAiClient(['not json at all', '123', _validSpec]);
      final service = LlmVideoAuthorService(client: client);

      final spec = await service.author('x');

      expect(spec.scenes, hasLength(1));
      expect(client.requests, hasLength(3));
      // The repair turns fed the error back as a growing conversation.
      expect(client.requests.last.messages.length, greaterThan(2));
      expect(
        client.requests.last.messages.last.text,
        contains('corrected JSON object'),
      );
    });

    test('throws after the repair budget is exhausted', () async {
      final service = LlmVideoAuthorService(
        client: FakeAiClient(['bad', 'bad', 'bad', 'bad']),
      );
      await expectLater(service.author('x'), throwsA(isA<AiClientException>()));
    });

    test('surfaces a client that runs out of replies', () async {
      final service = LlmVideoAuthorService(client: FakeAiClient(const []));
      await expectLater(service.author('x'), throwsA(isA<AiClientException>()));
    });

    test('a refinement includes the base spec in the prompt', () async {
      final base = VideoSpec.fromJson(
        const {
          'scenes': [
            {
              'duration': '2s',
              'children': [
                {'type': 'Text', 'text': 'Old'},
              ],
            },
          ],
        },
      );
      final client = FakeAiClient([_validSpec]);
      final service = LlmVideoAuthorService(client: client);

      await service.author('make the title yellow', base: base);

      final userMessage = client.requests.first.messages.last.text;
      expect(userMessage, contains('current spec'));
      expect(userMessage, contains('make the title yellow'));
    });
  });

  group('buildAuthorSystemPrompt', () {
    test('embeds the schema and the authoring rules', () {
      final prompt = buildAuthorSystemPrompt(videoSpecSchema);
      expect(prompt, contains('JSON Schema'));
      expect(prompt, contains('fadeIn'));
      expect(prompt, contains('"#RRGGBB"'));
    });
  });

  group('providers', () {
    test('aiClientProvider has no default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        () => container.read(aiClientProvider),
        throwsA(predicate<Object>((e) => e.toString().contains('Override aiClientProvider'))),
      );
    });

    test('videoAuthorServiceProvider builds on the overridden client', () async {
      final container = ProviderContainer(
        overrides: [
          aiClientProvider.overrideWithValue(FakeAiClient([_validSpec])),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(videoAuthorServiceProvider);
      final spec = await service.author('hi');
      expect(spec.scenes, hasLength(1));
    });
  });
}
