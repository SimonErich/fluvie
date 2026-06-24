import 'dart:convert';
import 'dart:typed_data';

import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const _creds = ProviderCredentials(apiKey: 'suno-key');
Future<void> _noSleep(Duration _) async {}

void main() {
  group('SunoMusicClient', () {
    test('submits, polls until an audio_url appears, fetches it', () async {
      final audio = Uint8List.fromList([5, 5, 5]);
      late http.Request submit;
      var polls = 0;
      final client = MockClient((request) async {
        final url = request.url.toString();
        if (request.method == 'POST' && url.contains('/api/v1/generate')) {
          submit = request;
          return http.Response(
            jsonEncode({
              'data': {'taskId': 'task-9'},
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (url.contains('task-9')) {
          polls++;
          if (polls < 2) {
            return http.Response(
              jsonEncode({
                'data': {'status': 'PENDING'},
              }),
              200,
              headers: const {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({
              'data': {
                'response': {
                  'sunoData': [
                    {'audioUrl': 'https://cdn.suno.test/song.mp3'},
                  ],
                },
              },
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (url.contains('song.mp3')) {
          return http.Response.bytes(audio, 200, headers: const {'content-type': 'audio/mpeg'});
        }
        return http.Response('unexpected', 404);
      });

      final generator = SunoMusicClient(credentials: _creds, httpClient: client, sleep: _noSleep);
      final stages = <GenerationStage>[];
      final result = await generator.generateMusic(
        const MusicRequest(prompt: 'lofi beats', instrumental: true, style: 'lofi', title: 'Chill'),
        onProgress: (p) => stages.add(p.stage),
      );
      expect(result.kind, MediaKind.music);
      expect(result.bytes, audio);
      expect(submit.headers['authorization'], 'Bearer suno-key');
      expect(stages, contains(GenerationStage.downloading));
      expect(stages.last, GenerationStage.done);
    });

    test('throws AiResponseException when submit returns no task id', () {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode({'data': <String, Object?>{}}),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      final generator = SunoMusicClient(credentials: _creds, httpClient: client, sleep: _noSleep);
      expect(
        () => generator.generateMusic(const MusicRequest(prompt: 'x')),
        throwsA(isA<AiResponseException>()),
      );
    });

    test('accepts a flat id field on submit', () async {
      final audio = Uint8List.fromList([1]);
      final client = MockClient((request) async {
        final url = request.url.toString();
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode({'id': 'flat-1'}),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (url.contains('flat-1')) {
          return http.Response(
            jsonEncode({
              'data': {
                'response': {
                  'sunoData': [
                    {'audioUrl': 'https://cdn.suno.test/a.mp3'},
                  ],
                },
              },
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        return http.Response.bytes(audio, 200, headers: const {'content-type': 'audio/mpeg'});
      });
      final generator = SunoMusicClient(credentials: _creds, httpClient: client, sleep: _noSleep);
      final result = await generator.generateMusic(const MusicRequest(prompt: 'x'));
      expect(result.bytes, audio);
    });
  });
}
