// Lanes in the printed Dart. Plain fluvie has no timeline, so a lane cannot
// be printed at all — but a muted one changes the mix, and printing a track
// the document silences would hand back code that renders something else.

import 'package:fluvie_cli/src/codegen/dart_spec_printer.dart';
import 'package:test/test.dart';

Map<String, Object?> _spec({List<Object?>? lanes, String? bedLane}) => {
  'fluvieSpec': 1,
  'lanes': ?lanes,
  'audio': [
    {
      'kind': 'music',
      'source': {'kind': 'asset', 'value': 'media/bed.mp3'},
      'lane': ?bedLane,
    },
  ],
  'scenes': [
    {
      'duration': '8s',
      'children': [
        {'id': 'el-title', 'type': 'Text', 'text': 'Lanes'},
      ],
    },
  ],
};

List<Object?> _lanes({bool muted = false}) => [
  {'id': 'v1', 'name': 'Video 1'},
  {'id': 'a1', 'name': 'Music', 'kind': 'audio', if (muted) 'muted': true},
];

void main() {
  test('a spec without lanes prints no heads-up comment', () {
    expect(printVideoSpecJson(_spec()), isNot(contains('// lanes:')));
  });

  test('lanes put a leading one-line comment counting them ahead of the code', () {
    final code = printVideoSpecJson(_spec(lanes: _lanes()));

    expect(code, contains('// lanes: this deck declares 2 timeline lanes;'));
    expect(code, contains('renders the same pixels without them'));
  });

  test('a lane-less deck still prints its audio', () {
    expect(printVideoSpecJson(_spec(bedLane: 'a1')), contains('Audio.music'));
  });

  test('a muted lane drops its tracks from the print', () {
    // The same rule the renderer follows. Code that plays a bed the document
    // silences is code that does not match its own spec.
    final code = printVideoSpecJson(_spec(lanes: _lanes(muted: true), bedLane: 'a1'));

    expect(code, isNot(contains('Audio.music')));
    expect(code, contains('1 muted lane (a1) had their audio left out'));
  });

  test('a track on an unmuted lane is printed as usual', () {
    final code = printVideoSpecJson(_spec(lanes: _lanes(), bedLane: 'a1'));

    expect(code, contains('Audio.music'));
    expect(code, isNot(contains('muted lane')));
  });

  test('the printed Dart still compiles to something with no audio argument', () {
    // Dropping the only track has to drop the whole argument, not leave an
    // empty list behind.
    final code = printVideoSpecJson(_spec(lanes: _lanes(muted: true), bedLane: 'a1'));

    expect(code, isNot(contains('audio: []')));
  });
}
