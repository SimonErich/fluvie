// Lanes: the rows a timeline draws bars on. They say where material is
// *shown*, never what order it paints in, and the one key that carries the
// reference is `lane` — `track` is already a content prop three times over.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/src/serialization/animation_catalog.dart';

Map<String, Object?> _deck({
  List<Object?>? lanes,
  String? elementLane,
  String? audioLane,
}) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'lanes': ?lanes,
  'audio': [
    {
      'kind': 'music',
      'source': {'kind': 'asset', 'value': 'audio/bed.mp3'},
      'lane': ?audioLane,
    },
  ],
  'scenes': [
    {
      'duration': '60f',
      'children': [
        {
          'id': 'el-a',
          'type': 'Text',
          'text': 'one',
          'lane': ?elementLane,
        },
      ],
    },
  ],
};

List<Object?> _lanes() => [
  {'id': 'v1', 'name': 'Video 1', 'kind': 'video'},
  {'id': 'a1', 'name': 'Music', 'kind': 'audio', 'muted': true, 'height': 56, 'locked': true},
];

VideoSpec _spec(Map<String, Object?> json) => VideoSpec.fromJson(json);

void main() {
  group('the lane list', () {
    test('reads its declarations', () {
      final spec = _spec(_deck(lanes: _lanes()));

      expect(spec.lanes, hasLength(2));
      expect(spec.lanes.first.id, 'v1');
      expect(spec.lanes.first.name, 'Video 1');
      expect(spec.lanes.first.kind, LaneKind.video);
      expect(spec.lanes.last.muted, isTrue);
      expect(spec.lanes.last.locked, isTrue);
      expect(spec.lanes.last.height, 56);
    });

    test('defaults everything a lane does not say', () {
      final spec = _spec(
        _deck(
          lanes: [
            {'id': 'v1'},
          ],
        ),
      );

      expect(spec.lanes.single.name, isNull);
      expect(spec.lanes.single.kind, LaneKind.video);
      expect(spec.lanes.single.locked, isFalse);
      expect(spec.lanes.single.muted, isFalse);
      expect(spec.lanes.single.height, isNull);
    });

    test('is empty in a document that never mentions one', () {
      expect(_spec(_deck()).lanes, isEmpty);
    });

    test('writes a canonical form, and a lane-less document grows no key', () {
      // Defaults are omitted, so a document that spells out `kind: video` and
      // one that leaves it alone are the same document and digest the same.
      final withLanes = _spec(_deck(lanes: _lanes())).toJson();

      expect(withLanes['lanes'], [
        {'id': 'v1', 'name': 'Video 1'},
        {'id': 'a1', 'name': 'Music', 'kind': 'audio', 'locked': true, 'muted': true, 'height': 56},
      ]);
      expect(_spec(_deck()).toJson().containsKey('lanes'), isFalse);
    });

    test('re-parses its own output to the same thing', () {
      final once = _spec(_deck(lanes: _lanes())).toJson();

      expect(VideoSpec.fromJson(once).toJson(), once);
    });

    test('refuses two lanes with one id', () {
      // A reference has to name exactly one row, or the timeline would draw
      // the same clip twice and honour whichever mute it read last.
      expect(
        () => _spec(
          _deck(
            lanes: [
              {'id': 'v1'},
              {'id': 'v1'},
            ],
          ),
        ),
        throwsA(isA<FluvieSpecError>()),
      );
    });

    test('refuses a lane with no id, which nothing could reference', () {
      expect(
        () => _spec(
          _deck(
            lanes: [
              {'name': 'Video 1'},
            ],
          ),
        ),
        throwsA(isA<FluvieSpecError>()),
      );
    });

    test('refuses a kind it does not know', () {
      expect(
        () => _spec(
          _deck(
            lanes: [
              {'id': 'v1', 'kind': 'hologram'},
            ],
          ),
        ),
        throwsA(isA<FluvieSpecError>()),
      );
    });
  });

  group('the reference', () {
    test('rides an element and survives a round-trip', () {
      final spec = _spec(_deck(lanes: _lanes(), elementLane: 'v1'));

      expect(spec.scenes.single.children.single.lane, 'v1');
      final json = spec.toJson()['scenes']! as List<Object?>;
      final element =
          ((json.single! as Map<String, Object?>)['children']! as List<Object?>).single!
              as Map<String, Object?>;
      expect(element['lane'], 'v1');
    });

    test('rides an audio track and survives a round-trip', () {
      final spec = _spec(_deck(lanes: _lanes(), audioLane: 'a1'));

      expect(spec.audio.single.lane, 'a1');
      expect((spec.toJson()['audio']! as List<Object?>).single, containsPair('lane', 'a1'));
    });

    test('never lands in an element props map', () {
      // A reserved key that leaked into props would be handed to the widget
      // as content, and a Text with a stray `lane` prop is a different Text.
      final spec = _spec(_deck(lanes: _lanes(), elementLane: 'v1'));

      expect(spec.scenes.single.children.single.props.containsKey('lane'), isFalse);
    });

    test('is refused when it names a lane the document never declared', () {
      expect(
        () => _spec(_deck(lanes: _lanes(), elementLane: 'nobody')),
        throwsA(isA<FluvieSpecError>()),
      );
      expect(
        () => _spec(_deck(lanes: _lanes(), audioLane: 'nobody')),
        throwsA(isA<FluvieSpecError>()),
      );
    });

    test('is refused in a document with no lanes at all', () {
      expect(() => _spec(_deck(elementLane: 'v1')), throwsA(isA<FluvieSpecError>()));
    });
  });

  group('a muted lane', () {
    test('drops the audio that rides it', () {
      // The one lane field that changes the render. A mute the export ignored
      // would be a lie the author only discovers in the file.
      final spec = _spec(_deck(lanes: _lanes(), audioLane: 'a1'));

      expect(spec.build().audio, isEmpty);
    });

    test('leaves audio on an unmuted lane alone', () {
      final spec = _spec(_deck(lanes: _lanes(), audioLane: 'v1'));

      expect(spec.build().audio, hasLength(1));
    });

    test('leaves audio on no lane at all alone', () {
      final spec = _spec(_deck(lanes: _lanes()));

      expect(spec.build().audio, hasLength(1));
    });

    test('moves the digest, because it moves the render', () {
      final muted = _spec(_deck(lanes: _lanes(), audioLane: 'a1')).digest();
      final playing = _spec(_deck(lanes: _lanes(), audioLane: 'v1')).digest();

      expect(muted, isNot(playing));
    });
  });

  group('the reserved keys', () {
    test('stay disjoint from every content prop Fluvie knows', () {
      // The whole reason the key is `lane` and not `track`: `track` is a
      // content prop three times over — the Bars beat grid, a music track's
      // anchor, and two reactive animation args. Reserving it would pull it
      // out of props and silently kill every beat grid while the round-trip
      // tests still passed. This guard stands whatever gets reserved next.
      final reserved = {...ElementSpec.reservedElementKeys, 'lane'};
      final content = <String>{
        for (final props in knownElementProps.values) ...props,
        for (final args in knownAnimationPresetArgs.values) ...args,
        ...knownKeyframesFormKeys,
      };

      expect(reserved.intersection(content), isEmpty);
    });

    test('and `track` is one of those content props, in all three places', () {
      expect(knownElementProps['Bars'], contains('track'));
      expect(AudioTrackSpec.musicKeys, contains('track'));
      expect(knownAnimationPresetArgs['pulse'], contains('track'));
    });
  });
}
