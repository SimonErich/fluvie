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
}
