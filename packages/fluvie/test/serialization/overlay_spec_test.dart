// Overlays: elements that live outside every scene, on the whole video's
// clock. One instance for the whole video, which is what a scene-paired
// morph can never be.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

Map<String, Object?> _deck({List<Object?>? overlays}) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'overlays': ?overlays,
  'scenes': [
    {
      'duration': '60f',
      'children': [
        {'id': 'el-a', 'type': 'Text', 'text': 'one'},
      ],
    },
    {
      'duration': '90f',
      'children': [
        {'id': 'el-b', 'type': 'Text', 'text': 'two'},
      ],
    },
  ],
};

List<Object?> _overlays() => [
  {
    'id': 'ov-logo',
    'type': 'Image',
    'source': {'kind': 'asset', 'value': 'images/logo.png'},
    'transform': {'x': 0.9, 'y': 0.1, 'w': 0.12, 'h': 0.12},
    'show': {'from': '0f', 'to': '150f'},
  },
];

VideoSpec _spec(Map<String, Object?> json) => VideoSpec.fromJson(json);

void main() {
  group('the overlay list', () {
    test('reads its elements', () {
      final spec = _spec(_deck(overlays: _overlays()));

      expect(spec.overlays, hasLength(1));
      expect(spec.overlays.single.id, 'ov-logo');
      expect(spec.overlays.single.type, 'Image');
    });

    test('is empty in a document that never mentions one', () {
      expect(_spec(_deck()).overlays, isEmpty);
    });

    test('round-trips, and a document without one grows no key', () {
      final json = _spec(_deck(overlays: _overlays())).toJson();

      expect((json['overlays']! as List<Object?>).single, containsPair('id', 'ov-logo'));
      expect(VideoSpec.fromJson(json).toJson(), json);
      expect(_spec(_deck()).toJson().containsKey('overlays'), isFalse);
    });

    test('keeps its window, which is the whole point of it', () {
      final spec = _spec(_deck(overlays: _overlays()));

      expect(spec.overlays.single.showFrom, isNotNull);
      expect(spec.overlays.single.showTo, isNotNull);
    });

    test('counts into the digest, because it renders', () {
      expect(_spec(_deck(overlays: _overlays())).digest(), isNot(_spec(_deck()).digest()));
    });
  });

  group('what an overlay may not do', () {
    test('declare shared, because it has no boundary to morph across', () {
      // A hero morph pairs two elements across a cut. An overlay is one
      // element for the whole video: there is no cut for it to cross, and a
      // pairing that named it would be pairing it with itself.
      expect(
        () => _spec(
          _deck(
            overlays: [
              {'id': 'ov-logo', 'type': 'Text', 'text': 'hi', 'shared': 'hero'},
            ],
          ),
        ),
        throwsA(isA<FluvieSpecError>()),
      );
    });

    test('hide a shared child inside a group, which would blame the wrong scene', () {
      // A hero nested in an overlay would parse, find no scene to pair with at
      // mount, and report the scene at the other end of the pair — the one
      // place the author did nothing wrong.
      expect(
        () => _spec(
          _deck(
            overlays: [
              {
                'id': 'ov',
                'type': 'Group',
                'children': [
                  {'id': 'ov-child', 'type': 'Text', 'text': 'hi', 'shared': 'hero'},
                ],
              },
            ],
          ),
        ),
        throwsA(isA<FluvieSpecError>()),
      );
    });

    test('be something other than an object', () {
      expect(() => _spec(_deck(overlays: ['nonsense'])), throwsA(isA<FluvieSpecError>()));
    });

    test('be an unknown element type, exactly like a scene child', () {
      expect(
        () => _spec(
          _deck(
            overlays: [
              {'id': 'ov', 'type': 'Hologram'},
            ],
          ),
        ),
        throwsA(isA<FluvieSpecError>()),
      );
    });

    test('carry an empty show object, exactly like a scene child', () {
      expect(
        () => _spec(
          _deck(
            overlays: [
              {'id': 'ov', 'type': 'Text', 'text': 'hi', 'show': <String, Object?>{}},
            ],
          ),
        ),
        throwsA(isA<FluvieSpecError>()),
      );
    });

    test('name a lane the document never declared', () {
      expect(
        () => _spec(
          _deck(
            overlays: [
              {'id': 'ov', 'type': 'Text', 'text': 'hi', 'lane': 'nobody'},
            ],
          ),
        ),
        throwsA(isA<FluvieSpecError>()),
      );
    });
  });

  group('the schema', () {
    test('does not advertise shared on an overlay, which the parser refuses', () {
      // Three artifacts accepting a shape the fourth rejects is how a
      // constrained-decoding model gets told a field is legal and then has its
      // output thrown away.
      final overlays = videoSpecSchema['properties']! as Map<String, Object?>;
      final items = (overlays['overlays']! as Map<String, Object?>)['items'];

      expect(items, {r'$ref': r'#/$defs/overlayElement'});

      final defs = videoSpecSchema[r'$defs']! as Map<String, Object?>;
      final variants = (defs['overlayElement']! as Map<String, Object?>)['oneOf']! as List<Object?>;
      for (final variant in variants.cast<Map<String, Object?>>()) {
        expect(
          (variant['properties']! as Map<String, Object?>).containsKey('shared'),
          isFalse,
          reason: '${variant['properties']}',
        );
      }
    });

    test('still advertises shared on a scene child, which is where a hero lives', () {
      final defs = videoSpecSchema[r'$defs']! as Map<String, Object?>;
      final variants = (defs['element']! as Map<String, Object?>)['oneOf']! as List<Object?>;

      expect(
        variants.cast<Map<String, Object?>>().every(
          (v) => (v['properties']! as Map<String, Object?>).containsKey('shared'),
        ),
        isTrue,
      );
    });
  });

  group('validation', () {
    test('names an unknown property on an overlay', () {
      final warnings = unknownSpecProps(
        _deck(
          overlays: [
            {'id': 'ov', 'type': 'Text', 'text': 'hi', 'wobble': 3},
          ],
        ),
      );

      expect(warnings, hasLength(1));
      expect(warnings.single.path, ['overlays', '0']);
      expect(warnings.single.message, contains('wobble'));
    });

    test('says nothing about a clean overlay', () {
      expect(unknownSpecProps(_deck(overlays: _overlays())), isEmpty);
    });
  });
}
