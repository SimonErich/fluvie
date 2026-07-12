import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

import 'poster_capture.dart';

Map<String, Object?> _specJson() => {
  'fluvieSpec': 1,
  'size': {'width': 64, 'height': 64},
  'fps': 30,
  'scenes': [
    {
      'duration': '1s',
      'background': {'kind': 'color', 'color': '#FF2030FF'},
      'children': [
        {
          'type': 'Text',
          'text': 'Hi',
          'animate': [
            {'preset': 'fadeIn'},
          ],
        },
      ],
    },
  ],
};

void main() {
  testWidgets('renders a spec poster to non-empty PNG bytes', (tester) async {
    final image = await renderPosterPng(tester: tester, spec: VideoSpec.fromJson(_specJson()));

    expect(image.mediaType, 'image/png');
    expect(image.bytes, isNotEmpty);
    // The PNG 8-byte signature.
    expect(image.bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });

  group('assertPosterSourcesAllowed', () {
    const file = FileSource('/etc/passwd');
    final network = NetworkSource(Uri.parse('http://169.254.169.254/latest/meta-data'));
    const asset = AssetSource('images/logo.png');
    final memory = MemorySource(Uint8List.fromList(const [1, 2, 3]));

    test('lets every source through on the trusted path (block off)', () {
      expect(
        () => assertPosterSourcesAllowed([file, network, asset, memory], block: false),
        returnsNormally,
      );
    });

    test('rejects a host file source on the hardened path', () {
      expect(
        () => assertPosterSourcesAllowed([asset, file], block: true),
        throwsA(isA<FluvieRenderException>()),
      );
    });

    test('rejects a network source on the hardened path', () {
      expect(
        () => assertPosterSourcesAllowed([network], block: true),
        throwsA(isA<FluvieRenderException>()),
      );
    });

    test('still allows bundled asset and in-spec memory sources when hardened', () {
      expect(() => assertPosterSourcesAllowed([asset, memory], block: true), returnsNormally);
    });
  });
}
