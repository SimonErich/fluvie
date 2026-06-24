import 'dart:convert';
import 'dart:typed_data';

import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const _creds = ProviderCredentials(apiKey: 'xi-key');

void main() {
  group('ElevenLabsSpeechClient', () {
    test('posts the text, returns mp3 bytes, uses the default voice', () async {
      final audio = Uint8List.fromList([1, 2, 3]);
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response.bytes(audio, 200, headers: const {'content-type': 'audio/mpeg'});
      });
      final generator = ElevenLabsSpeechClient(credentials: _creds, httpClient: client);
      final result = await generator.generateSpeech(const SpeechRequest(prompt: 'hello'));
      expect(result.kind, MediaKind.speech);
      expect(result.bytes, audio);
      expect(result.mimeType, 'audio/mpeg');
      expect(seen.headers['xi-api-key'], 'xi-key');
      expect(seen.url.path, contains('21m00Tcm4TlvDq8ikWAM'));
      expect((jsonDecode(seen.body) as Map)['text'], 'hello');
    });

    test('uses the voice from the request when provided', () async {
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response.bytes(
          Uint8List(1),
          200,
          headers: const {'content-type': 'audio/mpeg'},
        );
      });
      final generator = ElevenLabsSpeechClient(credentials: _creds, httpClient: client);
      await generator.generateSpeech(const SpeechRequest(prompt: 'hi', voice: 'voice-42'));
      expect(seen.url.path, contains('voice-42'));
    });

    test('maps a 401 to AiAuthException', () {
      final client = MockClient((_) async => http.Response('no', 401));
      final generator = ElevenLabsSpeechClient(credentials: _creds, httpClient: client);
      expect(
        () => generator.generateSpeech(const SpeechRequest(prompt: 'x')),
        throwsA(isA<AiAuthException>()),
      );
    });

    test('sends voice settings, honors an endpoint override, and emits lifecycle', () async {
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response.bytes(
          Uint8List.fromList(const [1]),
          200,
          headers: const {'content-type': 'audio/mpeg'},
        );
      });
      final generator = ElevenLabsSpeechClient(
        credentials: _creds,
        httpClient: client,
        endpoint: Uri.parse('https://proxy.test/v1/text-to-speech'),
      );
      final stages = <GenerationStage>[];
      await generator.generateSpeech(
        const SpeechRequest(prompt: 'hi', voice: 'v1', stability: 0.4, similarity: 0.8),
        onProgress: (p) => stages.add(p.stage),
      );
      expect(seen.url.host, 'proxy.test');
      expect(seen.url.path, endsWith('/v1'));
      final settings = (jsonDecode(seen.body) as Map)['voice_settings'] as Map;
      expect(settings['stability'], 0.4);
      expect(settings['similarity_boost'], 0.8);
      expect(stages, [GenerationStage.running, GenerationStage.done]);
    });
  });

  group('ElevenLabsSoundEffectClient', () {
    test('posts the prompt and returns mp3 bytes', () async {
      final audio = Uint8List.fromList([9, 9]);
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response.bytes(audio, 200, headers: const {'content-type': 'audio/mpeg'});
      });
      final generator = ElevenLabsSoundEffectClient(credentials: _creds, httpClient: client);
      final stages = <GenerationStage>[];
      final result = await generator.generateSoundEffect(
        const SoundEffectRequest(prompt: 'thunder', seconds: 3, promptInfluence: 0.5),
        onProgress: (p) => stages.add(p.stage),
      );
      expect(result.kind, MediaKind.soundEffect);
      expect(result.bytes, audio);
      expect(stages, [GenerationStage.running, GenerationStage.done]);
      final body = jsonDecode(seen.body) as Map<String, Object?>;
      expect(body['text'], 'thunder');
      expect(body['duration_seconds'], 3.0);
      expect(body['prompt_influence'], 0.5);
      expect(seen.url.path, contains('/v1/sound-generation'));
    });
  });
}
