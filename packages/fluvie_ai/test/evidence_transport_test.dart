import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_ai/fluvie_ai.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Future<AiImage> picture(ui.Color color) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(const ui.Rect.fromLTWH(0, 0, 4, 4), ui.Paint()..color = color);
  final recording = recorder.endRecording();
  final image = await recording.toImage(4, 4);
  try {
    return AiImage(
      bytes: (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List(),
    );
  } finally {
    image.dispose();
    recording.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final provider in ['ollama', 'mistral']) {
    test(
      '$provider transmits original selected pictures instead of discarding vision input',
      () async {
        final red = await picture(const ui.Color(0xffff0000));
        final green = await picture(const ui.Color(0xff00ff00));
        final httpClient = MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, Object?>;
          final turns = (body['messages']! as List<Object?>).cast<Map<String, Object?>>();
          final images = provider == 'ollama'
              ? turns.expand((turn) => (turn['images'] as List<Object?>?) ?? []).toList()
              : turns
                    .where((turn) => turn['content'] is List<Object?>)
                    .expand(
                      (turn) => (turn['content']! as List<Object?>).cast<Map<String, Object?>>(),
                    )
                    .where((part) => part['image_url'] != null)
                    .map(
                      (part) => ((part['image_url']! as Map<String, Object?>)['url']! as String)
                          .split(',')
                          .last,
                    )
                    .toList();
          expect(images, [base64Encode(red.bytes), base64Encode(green.bytes)]);
          return http.Response(
            provider == 'ollama'
                ? '{"message":{"content":"ok"},"done":true}'
                : '{"choices":[{"message":{"content":"ok"}}]}',
            200,
          );
        });
        final client = provider == 'ollama'
            ? OllamaAiClient(httpClient: httpClient)
            : MistralAiClient(apiKey: 'test', httpClient: httpClient);
        expect(
          (await client.generate(
            AiRequest(
              messages: [
                AiMessage.user('cat.mp4 at 1s', image: red),
                AiMessage.user('kitten.mp4 at 2s', image: green),
              ],
            ),
          )).text,
          'ok',
        );
      },
    );
  }
  test(
    'single-image provider receives every selected image in a bounded labeled composite',
    () async {
      final red = await picture(const ui.Color(0xffff0000));
      final green = await picture(const ui.Color(0xff00ff00));
      final client = GeminiAiClient(
        apiKey: 'test',
        httpClient: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, Object?>;
          final contents = (body['contents']! as List<Object?>).cast<Map<String, Object?>>();
          final images = contents
              .expand(
                (message) => (message['parts']! as List<Object?>).cast<Map<String, Object?>>(),
              )
              .where((part) => part['inlineData'] != null)
              .map((part) => (part['inlineData']! as Map<String, Object?>)['data'])
              .toList();
          expect(images, hasLength(1));
          final codec = await ui.instantiateImageCodec(base64Decode(images.single! as String));
          final decoded = (await codec.getNextFrame()).image;
          try {
            expect(decoded.width, 1024);
            expect(decoded.height, 1208);
            final data = (await decoded.toByteData())!.buffer.asUint8List();
            const redAt = (316 * 1024 + 512) * 4;
            const greenAt = (920 * 1024 + 512) * 4;
            expect(data.sublist(redAt, redAt + 4), [255, 0, 0, 255]);
            expect(data.sublist(greenAt, greenAt + 4), [0, 255, 0, 255]);
          } finally {
            decoded.dispose();
            codec.dispose();
          }
          return http.Response('{"candidates":[{"content":{"parts":[{"text":"ok"}]}}]}', 200);
        }),
      );
      final reply = await client.generate(
        AiRequest(
          messages: [
            const AiMessage.user('Compare the two supplied clips.'),
            AiMessage.user('cat.mp4 at 1s', image: red),
            AiMessage.user('kitten.mp4 at 2s', image: green),
          ],
        ),
      );
      expect(reply.text, 'ok');
    },
  );
}
