import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_ai/fluvie_ai.dart';

void main() {
  test('AiImage stores bytes and defaults to PNG', () {
    final image = AiImage(bytes: Uint8List.fromList(const [1, 2, 3]));
    expect(image.bytes, hasLength(3));
    expect(image.mediaType, 'image/png');
  });

  test('AiMessage variants set the role and carry an optional image', () {
    expect(const AiMessage.system('s').role, AiRole.system);
    expect(const AiMessage.assistant('a').role, AiRole.assistant);
    final withImage = AiMessage.user('u', image: AiImage(bytes: Uint8List(0)));
    expect(withImage.role, AiRole.user);
    expect(withImage.image, isNotNull);
  });

  test('AiRequest and AiResponse carry their payloads', () {
    const request = AiRequest(messages: [AiMessage.user('hi')]);
    expect(request.messages, hasLength(1));
    expect(request.maxTokens, greaterThan(0));
    expect(const AiResponse('out').text, 'out');
  });

  test('AiClientException reads its message', () {
    expect(AiClientException('boom').toString(), 'AiClientException: boom');
  });
}
