import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_ai/fluvie_ai.dart';

void main() {
  test('recording preserves request, reply and provider failure identity', () async {
    final records = <AiGenerationRecord>[];
    final provider = FakeAiClient(['reply']);
    final client = RecordingAiClient(client: provider, record: (value) async => records.add(value));
    const request = AiRequest(messages: [AiMessage.user('source')]);
    final reply = await client.generate(request);
    expect(records.single.request, same(request));
    expect(records.single.response, same(reply));
    expect(records.single.error, isNull);
    expect(client.supportsStructuredOutput, provider.supportsStructuredOutput);
    await expectLater(client.generate(request), throwsA(isA<AiClientException>()));
    expect(records, hasLength(2));
    expect(records.last.response, isNull);
    expect(records.last.error, isA<AiClientException>());
  });

  test('an unavailable evidence sink prevents success without the requested record', () async {
    final failure = StateError('disk full');
    final client = RecordingAiClient(
      client: FakeAiClient(['reply']),
      record: (_) async => throw failure,
    );
    await expectLater(
      client.generate(const AiRequest(messages: [AiMessage.user('source')])),
      throwsA(same(failure)),
    );
  });
}
