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

  test('generateAll reports generating/done progress, then cached on a hit', () async {
    final events = <String>[];
    void record(({int index, int total, String providerId, String stage}) p) =>
        events.add('${p.index}/${p.total} ${p.providerId} ${p.stage}');
    await resolver().generateAll([img], onProgress: record);
    expect(events, ['0/1 flux generating', '0/1 flux done']);
    events.clear();
    await resolver().generateAll([img], onProgress: record);
    expect(events, ['0/1 flux cached']);
  });

  test('wav and ogg mime types pick the matching cache extension', () async {
    const wav = GenerativeSource.music(providerId: 'suno', prompt: 'a wav track');
    const ogg = GenerativeSource.music(providerId: 'suno', prompt: 'an ogg track');
    final r = resolver(
      generate: (s) async => GenerationResult(
        bytes: Uint8List.fromList([1]),
        mimeType: s == wav ? 'audio/wav' : 'audio/ogg',
        kind: MediaKind.music,
        metadata: const GenerationMetadata(model: 'fake'),
      ),
    );
    await r.generateAll([wav, ogg]);
    expect(r.audioFor(wav), AudioSource.file('${tmp.path}/suno/${wav.cacheKey}.wav'));
    expect(r.audioFor(ogg), AudioSource.file('${tmp.path}/suno/${ogg.cacheKey}.ogg'));
    expect(File('${tmp.path}/suno/${wav.cacheKey}.wav').existsSync(), isTrue);
    expect(File('${tmp.path}/suno/${ogg.cacheKey}.ogg').existsSync(), isTrue);
  });

  test('an unknown mime type falls back to the extension for the media kind', () async {
    const rawImage = GenerativeSource.image(providerId: 'flux', prompt: 'a raw image');
    const rawVideo = GenerativeSource.video(providerId: 'veo', prompt: 'a raw video');
    final r = resolver(
      generate: (s) async => GenerationResult(
        bytes: Uint8List.fromList([2]),
        mimeType: 'application/octet-stream',
        kind: s == rawImage ? MediaKind.image : MediaKind.video,
        metadata: const GenerationMetadata(model: 'fake'),
      ),
    );
    await r.generateAll([rawImage, rawVideo]);
    expect(r.mediaFor(rawImage), MediaSource.file('${tmp.path}/flux/${rawImage.cacheKey}.png'));
    expect(r.mediaFor(rawVideo), MediaSource.file('${tmp.path}/veo/${rawVideo.cacheKey}.mp4'));
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
