import 'dart:io';
import 'dart:typed_data';

import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_ai/generative.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('fluvie_gen_wire_test_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  const speech = GenerativeSource.speech(providerId: 'elevenlabs', prompt: 'hi');
  final audio = Uint8List.fromList([1, 2, 3]);

  test('without a generate seam the resolver calls the provider over http', () async {
    late http.Request seen;
    final client = MockClient((request) async {
      seen = request;
      return http.Response.bytes(audio, 200, headers: const {'content-type': 'audio/mpeg'});
    });
    final resolver = GenerativeMediaResolver(
      config: GenerativeConfig(
        credentials: const {ProviderId.elevenLabs: ProviderCredentials(apiKey: 'xi-key')},
        cacheDir: tmp.path,
      ),
      httpClient: client,
    );
    await resolver.generateAll([speech]);
    expect(seen.method, 'POST');
    expect(seen.headers['xi-api-key'], 'xi-key');
    final path = '${tmp.path}/elevenlabs/${speech.cacheKey}.mp3';
    expect(resolver.audioFor(speech), AudioSource.file(path));
    expect(File(path).readAsBytesSync(), audio);
  });

  test('missing credentials for the provider throw at generate time', () async {
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return http.Response('unexpected', 404);
    });
    final resolver = GenerativeMediaResolver(
      config: GenerativeConfig(cacheDir: tmp.path),
      httpClient: client,
    );
    await expectLater(
      resolver.generateAll([speech]),
      throwsA(
        isA<FluvieGenerativeException>().having(
          (e) => e.message,
          'message',
          contains('No API credentials for provider "elevenlabs"'),
        ),
      ),
    );
    expect(requests, 0);
  });

  test('fromEnv reads the provider key and cache dir from the env map', () async {
    late http.Request seen;
    final client = MockClient((request) async {
      seen = request;
      return http.Response.bytes(audio, 200, headers: const {'content-type': 'audio/mpeg'});
    });
    final resolver = GenerativeMediaResolver.fromEnv({
      'ELEVENLABS_API_KEY': 'env-key',
      'FLUVIE_GENERATIVE_CACHE_DIR': tmp.path,
    }, httpClient: client);
    await resolver.generateAll([speech]);
    expect(seen.headers['xi-api-key'], 'env-key');
    expect(
      resolver.audioFor(speech),
      AudioSource.file('${tmp.path}/elevenlabs/${speech.cacheKey}.mp3'),
    );
  });
}
