// Overlays in the printed Dart. They render, so they print as the Video's own
// argument rather than as a comment about something plain fluvie cannot say.

import 'package:fluvie_cli/src/codegen/dart_spec_printer.dart';
import 'package:test/test.dart';

Map<String, Object?> _spec({List<Object?>? overlays}) => {
  'fluvieSpec': 1,
  'overlays': ?overlays,
  'scenes': [
    {
      'duration': '8s',
      'children': [
        {'id': 'el-title', 'type': 'Text', 'text': 'Scene one'},
      ],
    },
  ],
};

void main() {
  test('a spec without overlays prints no overlays argument', () {
    expect(printVideoSpecJson(_spec()), isNot(contains('overlays:')));
  });

  test('an overlay prints inside the Video, outside every Scene', () {
    final code = printVideoSpecJson(
      _spec(
        overlays: [
          {'id': 'ov-logo', 'type': 'Text', 'text': 'Logo'},
        ],
      ),
    );

    expect(code, contains('overlays: ['));
    expect(code, contains("Text('Logo')"));
    // The argument sits on the Video, before its scenes, exactly where the
    // real constructor takes it.
    expect(code.indexOf('overlays:'), lessThan(code.indexOf('scenes:')));
  });

  test('an overlay window prints as the animate window, exactly as a child does', () {
    final code = printVideoSpecJson(
      _spec(
        overlays: [
          {
            'id': 'ov',
            'type': 'Text',
            'text': 'live',
            'show': {'from': '45f', 'to': '180f'},
          },
        ],
      ),
    );

    expect(code, contains('.animate([], window: TimeRange(45.frames, 180.frames))'));
  });

  test('an overlay anchor is declared before the body that references it', () {
    // The anchor collector walks the overlays first for exactly this reason:
    // a declaration that printed after its use would not compile.
    final code = printVideoSpecJson(
      _spec(
        overlays: [
          {'id': 'ov', 'type': 'Text', 'text': 'live', 'anchor': 'ticker'},
        ],
      ),
    );

    expect(code, contains('ticker'));
    expect(code.indexOf('final ticker'), lessThan(code.indexOf('overlays:')));
  });
}
