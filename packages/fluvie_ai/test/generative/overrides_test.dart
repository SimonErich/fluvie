import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_ai/generative.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('fluvie_gen_overrides_test_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  const img = GenerativeSource.image(providerId: 'flux', prompt: 'a cat');

  test('defaultGenerativeCacheDir is .fluvie/generative under the working directory', () {
    expect(defaultGenerativeCacheDir(), '${Directory.current.path}/.fluvie/generative');
  });

  test('fluvieGenerativeResolverFor uses an explicit config as given', () async {
    final resolver = fluvieGenerativeResolverFor(
      config: GenerativeConfig(cacheDir: tmp.path, offline: true),
    );
    expect(resolver, isA<GenerativeMediaResolver>());
    await expectLater(
      resolver.generateAll([img]),
      throwsA(
        isA<FluvieGenerativeException>().having((e) => e.message, 'message', contains('Offline')),
      ),
    );
  });

  test('fluvieGenerativeResolverFor builds the config from the given env', () async {
    final resolver = fluvieGenerativeResolverFor(
      env: {'FLUVIE_GENERATIVE_CACHE_DIR': tmp.path, 'FLUVIE_GENERATIVE_OFFLINE': '1'},
    );
    expect(resolver, isA<GenerativeMediaResolver>());
    await expectLater(
      resolver.generateAll([img]),
      throwsA(
        isA<FluvieGenerativeException>().having((e) => e.message, 'message', contains('Offline')),
      ),
    );
  });
}
