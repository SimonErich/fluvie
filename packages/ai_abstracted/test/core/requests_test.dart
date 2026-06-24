import 'dart:typed_data';

import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:test/test.dart';

void main() {
  group('ImageRequest', () {
    test('kind and fields', () {
      const request = ImageRequest(
        prompt: 'a cat',
        width: 1024,
        height: 768,
        aspectRatio: '4:3',
        negativePrompt: 'blurry',
        extra: {'guidance': 7},
      );
      expect(request.kind, MediaKind.image);
      expect(request.width, 1024);
      expect(request.height, 768);
      expect(request.aspectRatio, '4:3');
      expect(request.negativePrompt, 'blurry');
      expect(request.extra['guidance'], 7);
    });

    test('extra defaults to empty', () {
      expect(const ImageRequest(prompt: 'x').extra, isEmpty);
    });
  });

  group('VideoRequest', () {
    test('kind, defaults and fields', () {
      const request = VideoRequest(
        prompt: 'a dog running',
        seconds: 8,
        width: 1920,
        height: 1080,
        fps: 24,
        aspectRatio: '16:9',
      );
      expect(request.kind, MediaKind.video);
      expect(request.withAudio, isTrue);
      expect(request.seconds, 8);
      expect(request.fps, 24);
      expect(request.aspectRatio, '16:9');
    });

    test('withAudio can be disabled', () {
      expect(const VideoRequest(prompt: 'x', withAudio: false).withAudio, isFalse);
    });
  });

  group('SpeechRequest', () {
    test('kind, defaults and fields', () {
      const request = SpeechRequest(
        prompt: 'hello there',
        voice: 'rachel',
        stability: 0.5,
        similarity: 0.7,
      );
      expect(request.kind, MediaKind.speech);
      expect(request.format, 'mp3');
      expect(request.voice, 'rachel');
      expect(request.stability, 0.5);
      expect(request.similarity, 0.7);
    });

    test('format override', () {
      expect(const SpeechRequest(prompt: 'x', format: 'wav').format, 'wav');
    });
  });

  group('SoundEffectRequest', () {
    test('kind, defaults and fields', () {
      const request = SoundEffectRequest(
        prompt: 'thunder',
        seconds: 3,
        promptInfluence: 0.4,
      );
      expect(request.kind, MediaKind.soundEffect);
      expect(request.format, 'mp3');
      expect(request.seconds, 3);
      expect(request.promptInfluence, 0.4);
    });
  });

  group('MusicRequest', () {
    test('kind, defaults and fields', () {
      const request = MusicRequest(
        prompt: 'lofi beats',
        seconds: 30,
        title: 'Study',
        style: 'lofi',
      );
      expect(request.kind, MediaKind.music);
      expect(request.instrumental, isFalse);
      expect(request.format, 'mp3');
      expect(request.seconds, 30);
      expect(request.title, 'Study');
      expect(request.style, 'lofi');
    });

    test('instrumental override', () {
      expect(const MusicRequest(prompt: 'x', instrumental: true).instrumental, isTrue);
    });
  });

  group('TextRequest', () {
    test('kind, defaults and fields', () {
      const request = TextRequest(
        prompt: 'summarize',
        system: 'be terse',
        temperature: 0.2,
        jsonSchema: {'type': 'object'},
      );
      expect(request.kind, MediaKind.text);
      expect(request.maxTokens, 4096);
      expect(request.system, 'be terse');
      expect(request.temperature, 0.2);
      expect(request.jsonSchema, {'type': 'object'});
    });

    test('maxTokens override', () {
      expect(const TextRequest(prompt: 'x', maxTokens: 100).maxTokens, 100);
    });

    test('history defaults to empty and image to null', () {
      const request = TextRequest(prompt: 'x');
      expect(request.history, isEmpty);
      expect(request.image, isNull);
    });

    test('carries a conversation history and an attached image', () {
      final request = TextRequest(
        prompt: 'and now?',
        history: const [TextMessage.user('hi'), TextMessage.assistant('hello')],
        image: TextImage(bytes: Uint8List.fromList(const [1, 2])),
      );
      expect(request.history, hasLength(2));
      expect(request.history.first.role, TextRole.user);
      expect(request.image!.bytes, [1, 2]);
    });
  });
}
