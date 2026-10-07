import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_ai/fluvie_ai.dart';
import 'package:fluvie_ai/src/client/evidence_image_composer.dart';
import 'package:fluvie_ai/src/client/vision_chat_transport.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final response in [
    http.Response('rejected', 403),
    http.Response('[]', 200),
    http.Response('{', 200),
    http.Response('{"choices":[]}', 200),
  ]) {
    test(
      'vision reports unusable provider response ${response.statusCode}: ${response.body}',
      () async {
        final client = MockClient((_) async => response);
        addTearDown(client.close);
        await expectLater(
          generateVisionChat(
            const AiRequest(messages: [AiMessage.user('Inspect')]),
            model: 'fixture',
            endpoint: Uri.parse('https://fixture.invalid'),
            ollama: false,
            httpClient: client,
          ),
          throwsA(isA<AiClientException>()),
        );
      },
    );
  }
  test(
    'vision connection failures give a useful error without leaking transport details',
    () async {
      final client = MockClient(
        (_) async => throw http.ClientException('private transport detail'),
      );
      addTearDown(client.close);
      await expectLater(
        generateVisionChat(
          const AiRequest(messages: [AiMessage.user('Inspect')]),
          model: 'fixture',
          endpoint: Uri.parse('https://fixture.invalid'),
          ollama: true,
          httpClient: client,
        ),
        throwsA(isA<AiClientException>().having((e) => e.message, 'message', contains('endpoint'))),
      );
    },
  );
  test('one oversized reference is rejected before decoding or a provider call', () async {
    final image = AiImage(bytes: Uint8List(4 * 1024 * 1024 + 1));
    final turns = [AiMessage.user('Inspect', image: image)];
    await expectLater(composeEvidenceImage(turns), throwsA(isA<AiClientException>()));
    await expectLater(
      generateVisionChat(
        AiRequest(messages: turns),
        model: 'fixture',
        endpoint: Uri.parse('https://fixture.invalid'),
        ollama: false,
      ),
      throwsA(isA<AiClientException>()),
    );
  });
  test('invalid encoded references fail explicitly and release partial decode state', () async {
    final image = AiImage(bytes: Uint8List.fromList([1, 2, 3]));
    await expectLater(
      composeEvidenceImage([AiMessage.user('A', image: image), AiMessage.user('B', image: image)]),
      throwsA(isA<AiClientException>()),
    );
    expect(await composeEvidenceImage(const [AiMessage.user('No image')]), isNull);
  });
}
