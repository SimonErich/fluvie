import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_mobile_encoder/fluvie_mobile_encoder.dart';

/// A canned [AssetBundle] serving fixed bytes per key.
class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this._bytes);

  final Map<String, List<int>> _bytes;

  @override
  Future<ByteData> load(String key) async {
    final data = _bytes[key];
    if (data == null) throw StateError('no asset "$key"');
    return ByteData.view(Uint8List.fromList(data).buffer);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('materializes a bundled asset to a local file', () async {
    final cache = Directory.systemTemp.createTempSync('mat_');
    addTearDown(() => cache.deleteSync(recursive: true));
    final materializer = BundleAudioMaterializer(
      bundle: _FakeBundle({
        'audio/song.mp3': const [1, 2, 3, 4],
      }),
      cacheDir: cache,
    );

    final path = await materializer.materialize('audio/song.mp3');

    expect(File(path).existsSync(), isTrue);
    expect(File(path).readAsBytesSync(), const [1, 2, 3, 4]);
  });

  test('passes an absolute file path straight through', () async {
    final materializer = BundleAudioMaterializer(bundle: _FakeBundle(const {}));
    expect(await materializer.materialize('/music/bed.m4a'), '/music/bed.m4a');
  });

  test('rejects a network source with a typed error', () async {
    final materializer = BundleAudioMaterializer(bundle: _FakeBundle(const {}));
    await expectLater(
      materializer.materialize('https://example.com/song.mp3'),
      throwsA(
        isA<FluvieMobileEncoderException>().having(
          (e) => e.code,
          'code',
          'unsupported_audio_source',
        ),
      ),
    );
  });

  test('defaults to the root asset bundle', () {
    expect(BundleAudioMaterializer().bundle, isNotNull);
  });
}
