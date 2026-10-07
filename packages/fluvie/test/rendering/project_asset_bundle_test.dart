import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/rendering.dart';

class _Bundle extends CachingAssetBundle {
  _Bundle(this.data);
  final Map<String, ByteData> data;
  @override
  Future<ByteData> load(String key) async =>
      data[key] ?? (throw FlutterError('Unable to load asset: $key'));
}

ByteData _bytes(String text) => ByteData.sublistView(Uint8List.fromList(utf8.encode(text)));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('recursive dropped assets preserve pubspec, package assets and declared variants', () async {
    final project = Directory.systemTemp.createTempSync('fluvie_assets_');
    addTearDown(() => project.deleteSync(recursive: true));
    File(
      '${project.path}/pubspec.yaml',
    ).writeAsStringSync('name: demo\nflutter:\n  assets:\n    - existing/\n');
    final original = File('${project.path}/pubspec.yaml').readAsStringSync();
    Directory('${project.path}/assets/cat/2.0x').createSync(recursive: true);
    File('${project.path}/assets/cat/photo.png').writeAsStringSync('photo');
    File('${project.path}/assets/cat/2.0x/photo.png').writeAsStringSync('large');
    File('${project.path}/assets/cat/story.txt').writeAsStringSync('Life of my cat');
    final fallback = _Bundle({
      'AssetManifest.bin': const StandardMessageCodec().encodeMessage({
        'existing/logo.png': [
          {'asset': 'existing/logo.png'},
          {'asset': 'existing/3.0x/logo.png', 'dpr': 3.0},
        ],
        'packages/library/icon.png': [
          {'asset': 'packages/library/icon.png'},
        ],
      })!,
      'packages/library/icon.png': _bytes('package'),
      'FontManifest.json': _bytes('[{"family":"packages/library/Font","fonts":[]}]'),
    });
    final bundle = await ProjectAssetBundle.fromProject(project.path, fallback: fallback);
    final manifest = await AssetManifest.loadFromAssetBundle(bundle);
    expect(
      manifest.listAssets(),
      containsAll([
        'assets/cat/photo.png',
        'assets/cat/story.txt',
        'existing/logo.png',
        'packages/library/icon.png',
      ]),
    );
    expect(
      manifest.getAssetVariants('assets/cat/photo.png')!.map((v) => v.targetDevicePixelRatio),
      [2.0, null],
    );
    expect(manifest.getAssetVariants('existing/logo.png')!.last.targetDevicePixelRatio, 3);
    expect(await bundle.loadString('assets/cat/story.txt'), 'Life of my cat');
    expect(await bundle.loadString('packages/library/icon.png'), 'package');
    expect(await bundle.loadString('FontManifest.json'), contains('packages/library/Font'));
    expect(File('${project.path}/pubspec.yaml').readAsStringSync(), original);
  });

  test('web and native manifests encode the same merged inventory', () async {
    final bundle = ProjectAssetBundle(
      assets: ['assets/a.txt'],
      readAsset: (_) async => _bytes('a'),
      fallback: _Bundle({}),
    );
    final binary = await bundle.load('AssetManifest.bin');
    final wrapped = jsonDecode(await bundle.loadString('AssetManifest.bin.json')) as String;
    expect(
      base64Decode(wrapped),
      binary.buffer.asUint8List(binary.offsetInBytes, binary.lengthInBytes),
    );
    expect((const StandardMessageCodec().decodeMessage(binary)! as Map<Object?, Object?>).keys, [
      'assets/a.txt',
    ]);
  });
}
