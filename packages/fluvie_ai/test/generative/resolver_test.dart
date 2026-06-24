import 'dart:io';
import 'dart:typed_data';

import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_ai/generative.dart';

GenerationResult _image() => GenerationResult(
  bytes: Uint8List.fromList([1, 2, 3]),
  mimeType: 'image/png',
  kind: MediaKind.image,
  metadata: const GenerationMetadata(model: 'fake', width: 512, height: 512),
);

GenerationResult _music() => GenerationResult(
  bytes: Uint8List.fromList([4, 5]),
  mimeType: 'audio/mpeg',
  kind: MediaKind.music,
  metadata: const GenerationMetadata(model: 'fake', durationMs: 10000),
);

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('fluvie_gen_test_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  GenerativeMediaResolver resolver({GenerateFn? generate, bool offline = false, int? budget}) =>
      GenerativeMediaResolver(
        config: GenerativeConfig(cacheDir: tmp.path, offline: offline, maxGenerations: budget),
        generate: generate ?? (_) async => _image(),
      );

  const img = GenerativeSource.image(providerId: 'flux', prompt: 'a cat');
  const music = GenerativeSource.music(providerId: 'suno', prompt: 'lofi');

  test('generates on a cache miss and serves a file-backed media source', () async {
    final r = resolver();
    await r.generateAll([img]);
    final expectedPath = '${tmp.path}/flux/${img.cacheKey}.png';
    expect(r.mediaFor(img), MediaSource.file(expectedPath));
    expect(File(expectedPath).existsSync(), isTrue);
    expect(File('${tmp.path}/flux/${img.cacheKey}.json').existsSync(), isTrue);
    expect(r.metaFor(img).width, 512);
  });

  test('a second resolver over the same cache dir is a hit (no generate call)', () async {
    await resolver().generateAll([img]);
    var calls = 0;
    final r2 = resolver(
      generate: (_) async {
        calls++;
        return _image();
      },
    );
    await r2.generateAll([img]);
    expect(calls, 0);
    expect(r2.mediaFor(img), MediaSource.file('${tmp.path}/flux/${img.cacheKey}.png'));
  });

  test('is idempotent within one resolver (generates once)', () async {
    var calls = 0;
    final r = resolver(
      generate: (_) async {
        calls++;
        return _image();
      },
    );
    await r.generateAll([img]);
    await r.generateAll([img]);
    expect(calls, 1);
  });

  test('an audio source resolves to a file-backed AudioSource', () async {
    final r = resolver(generate: (_) async => _music());
    await r.generateAll([music]);
    expect(r.audioFor(music), AudioSource.file('${tmp.path}/suno/${music.cacheKey}.mp3'));
    expect(r.metaFor(music).duration, const Duration(seconds: 10));
  });

  test('offline + cache miss throws a clear FluvieGenerativeException', () async {
    await expectLater(
      resolver(offline: true).generateAll([img]),
      throwsA(
        isA<FluvieGenerativeException>().having((e) => e.message, 'message', contains('Offline')),
      ),
    );
  });

  test('exceeding the generation budget throws', () async {
    await expectLater(
      resolver(budget: 0).generateAll([img]),
      throwsA(
        isA<FluvieGenerativeException>().having((e) => e.message, 'message', contains('budget')),
      ),
    );
  });

  test('a provider AiException maps to a FluvieGenerativeException naming it', () async {
    final r = resolver(generate: (_) async => throw AiException('boom', provider: 'flux'));
    await expectLater(
      r.generateAll([img]),
      throwsA(
        isA<FluvieGenerativeException>().having((e) => e.message, 'message', contains('boom')),
      ),
    );
  });

  test('reading before generateAll throws', () {
    expect(() => resolver().mediaFor(img), throwsA(isA<FluvieGenerativeException>()));
  });

  test('GenerativeConfig.fromEnv reads keys, cache dir, and offline', () {
    final config = GenerativeConfig.fromEnv(const {
      'BFL_API_KEY': 'k',
      'FLUVIE_GENERATIVE_CACHE_DIR': '/tmp/x',
      'FLUVIE_GENERATIVE_OFFLINE': '1',
    });
    expect(config.cacheDir, '/tmp/x');
    expect(config.offline, isTrue);
    expect(config.credentials[ProviderId.flux]?.apiKey, 'k');
  });
}
