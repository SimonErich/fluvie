import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_ai/fluvie_ai.dart';

void main() {
  test('Dart edits repair malformed replies and preserve unrelated source bytes', () async {
    final client = FakeAiClient([
      '{"explanation":"wrong shape"}',
      '{"edits":[{"before":"Milo plays","after":"Milo rests"}]}',
    ]);
    final service = DartEditService(client: client);
    final reply = await service.edit(
      'Change the title',
      source: 'Milo plays; custom widget unchanged',
    );
    expect(reply, contains('Milo rests'));
    expect(client.requests, hasLength(2));
    expect(client.requests.last.messages.last.text, contains('only an edits array'));
    expect(client.requests.first.jsonSchema, isNotNull);
  });

  test('ambiguous replacement ranges retry within a fixed request budget', () async {
    final client = FakeAiClient(List.filled(3, '{"edits":[{"before":"x","after":"y"}]}'));
    await expectLater(
      DartEditService(client: client).edit('Change x', source: 'x x'),
      throwsA(isA<AiClientException>()),
    );
    expect(client.requests, hasLength(3));
  });
  test('repair feedback identifies a token duplicated inside a fractional duration', () async {
    final client = FakeAiClient([
      '{"edits":[{"before":"3.seconds","after":"4.seconds"}]}',
      '{"edits":[{"before":"duration: 3.seconds","after":"duration: 4.seconds"}]}',
    ]);
    await DartEditService(
      client: client,
    ).edit('Lengthen the scene', source: 'duration: 3.seconds, delay: 0.3.seconds');
    final feedback = client.requests.last.messages.last.text;
    expect(feedback, contains('"3.seconds"'));
    expect(feedback, contains('surrounding Dart'));
  });
}
