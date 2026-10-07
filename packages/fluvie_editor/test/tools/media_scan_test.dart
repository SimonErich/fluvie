import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

void main() {
  test('usedMediaSources lists each source once, videos flagged', () {
    final document = EditorDocument.fromJson(const {
      'fluvieSpec': 1,
      'size': 'hd',
      'fps': 30,
      'scenes': [
        {
          'duration': '60f',
          'children': [
            {
              'type': 'Image',
              'source': {'kind': 'asset', 'value': 'a.png'},
            },
            {
              'type': 'Clip',
              'source': {'kind': 'file', 'value': '/tmp/b.mp4'},
              'poster': {'kind': 'asset', 'value': 'p.png'},
            },
          ],
        },
        {
          'duration': '30f',
          'children': [
            {
              'type': 'Image',
              'source': {'kind': 'asset', 'value': 'a.png'},
            },
            {'type': 'Text', 'text': 'no media'},
          ],
        },
      ],
    });
    final used = usedMediaSources(document);
    expect(used, hasLength(3));
    expect(
      used,
      containsAll([
        const MediaPick(source: {'kind': 'asset', 'value': 'a.png'}, isVideo: false),
        const MediaPick(source: {'kind': 'file', 'value': '/tmp/b.mp4'}, isVideo: true),
        const MediaPick(source: {'kind': 'asset', 'value': 'p.png'}, isVideo: false),
      ]),
    );
  });

  test('an empty deck has no media', () {
    final document = EditorDocument.fromJson(const {
      'fluvieSpec': 1,
      'size': 'hd',
      'fps': 30,
      'scenes': [
        {'duration': '60f', 'children': <Object?>[]},
      ],
    });
    expect(usedMediaSources(document), isEmpty);
  });
  pickEqualitySuite();
}

// MediaPick equality backs the reuse list's dedup and the tests' matchers.
void pickEqualitySuite() {
  test('MediaPick compares by source and kind', () {
    // ignore: prefer_const_constructors, a const pair would be identical and never run ==.
    final pick = MediaPick(source: const {'kind': 'asset', 'value': 'a.png'}, isVideo: false);
    expect(pick, const MediaPick(source: {'kind': 'asset', 'value': 'a.png'}, isVideo: false));
    expect(
      pick.hashCode,
      const MediaPick(source: {'kind': 'asset', 'value': 'a.png'}, isVideo: false).hashCode,
    );
    expect(
      pick,
      isNot(const MediaPick(source: {'kind': 'asset', 'value': 'a.png'}, isVideo: true)),
    );
    expect(pick.toString(), contains('a.png'));
  });
}
