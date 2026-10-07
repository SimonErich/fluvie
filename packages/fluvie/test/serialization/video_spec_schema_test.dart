import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

Map<String, Object?> _map(Object? value) => value! as Map<String, Object?>;
List<Object?> _list(Object? value) => value! as List<Object?>;
Map<String, Object?> _defs() => _map(videoSpecSchema[r'$defs']);

/// The per-type element (or per-kind background) def whose discriminator
/// `const` equals [discriminator], from a `oneOf` list.
Map<String, Object?> _variant(String defName, String key, String discriminator) {
  final oneOf = _list(_map(_defs()[defName])['oneOf']);
  return oneOf.map(_map).firstWhere((variant) {
    final discr = _map(_map(variant['properties'])[key]);
    return discr['const'] == discriminator;
  });
}

Set<String> _contentProps(Map<String, Object?> def, Set<String> reserved) =>
    _map(def['properties']).keys.toSet().difference(reserved);

void main() {
  group('videoSpecSchema is closed and matches the parser constants', () {
    test('the document root allows exactly the keys VideoSpec reads', () {
      expect(videoSpecSchema['additionalProperties'], isFalse);
      expect(_map(videoSpecSchema['properties']).keys.toSet(), VideoSpec.knownKeys);
    });

    test('a scene allows exactly the keys SceneSpec reads', () {
      expect(_map(_defs()['scene'])['additionalProperties'], isFalse);
      expect(_map(_map(_defs()['scene'])['properties']).keys.toSet(), SceneSpec.knownKeys);
    });

    test('a prop name shared by two element types keeps each type its own shape', () {
      // `speed` is a Time on Typewriter (how fast it types) and a number
      // or keyframed number on Clip (a playback rate). The prop-schema switch is keyed on the prop
      // name, so an unguarded arm would hand the clip's rate a time-string
      // schema: "speed": 0.5 would be rejected and "speed": "500ms" accepted.
      final clip = _map(_map(_variant('element', 'type', 'Clip')['properties'])['speed']);
      final typewriter = _map(
        _map(_variant('element', 'type', 'Typewriter')['properties'])['speed'],
      );

      final branches = _list(clip['oneOf']).map(_map).toList();
      expect(branches.first['type'], 'number', reason: 'scalar rates still permit reverse');
      expect(branches.first.containsKey('minimum'), isFalse);
      expect(branches.first['not'], {'const': 0});
      final ramp = _list(branches.last['allOf']).map(_map).toList();
      expect(ramp.first[r'$ref'], r'#/$defs/keyframedNumber');
      final rates = _map(_map(_map(ramp.last['properties'])['values'])['items']);
      expect(rates['exclusiveMinimum'], 0, reason: 'keyframed rates must remain positive');
      expect(typewriter[r'$ref'], r'#/$defs/time', reason: 'a typewriter speed is a duration');
    });

    test('speed schema positivity agrees with the parser while scalar reverse remains valid', () {
      VideoSpec document(Object speed) => VideoSpec.fromJson({
        'fluvieSpec': 1,
        'scenes': [
          {
            'duration': '1s',
            'children': [
              {
                'type': 'Clip',
                'source': {'kind': 'asset', 'value': 'clip.mp4'},
                'speed': speed,
              },
            ],
          },
        ],
      });
      for (final rate in [-1, 0]) {
        expect(
          () => document({
            'values': [rate, 1],
            'positions': ['0r', '1r'],
          }).build(),
          throwsA(isA<FluvieSpecError>()),
        );
      }
      expect(() => document(0).build(), throwsA(isA<FluvieSpecError>()));
      expect(() => document(-1).build(), returnsNormally);
      expect(
        () => document({
          'values': [0.25, 4],
          'positions': ['0r', '1r'],
        }).build(),
        returnsNormally,
      );
    });

    test('every element type is a closed variant over its known props', () {
      const reserved = ElementSpec.reservedElementKeys;
      for (final type in knownElementTypes) {
        final def = _variant('element', 'type', type);
        expect(def['additionalProperties'], isFalse, reason: '$type must be closed');
        expect(
          _contentProps(def, reserved),
          knownElementProps[type],
          reason: '$type schema props must match knownElementProps',
        );
      }
    });

    test('a keyframed effect parameter carries the same range its stops face', () {
      // The literal branch is bounded; the keyframed branch must bound every
      // stop the same way, or a constrained decoder would be told a ramp to
      // 5 is legal and then have its output refused.
      final amount = _map(_map(_variant('effect', 'kind', 'grain')['properties'])['amount']);
      final branches = (amount['oneOf']! as List).map(_map).toList();
      final keyframed = branches.last['allOf']! as List;

      expect(branches.first['minimum'], 0);
      expect(branches.first['maximum'], 1);
      expect(_map(keyframed.first)[r'$ref'], r'#/$defs/keyframedNumber');
      final bounds = _map(_map(_map(keyframed.last)['properties'])['values'])['items'];
      expect(_map(bounds)['minimum'], 0);
      expect(_map(bounds)['maximum'], 1);
    });

    test('every background kind is a closed variant over its known props', () {
      for (final kind in knownBackgroundKinds) {
        final def = _variant('background', 'kind', kind);
        expect(def['additionalProperties'], isFalse, reason: '$kind must be closed');
        expect(
          _contentProps(def, {'kind'}),
          knownBackgroundProps[kind],
          reason: '$kind schema props must match knownBackgroundProps',
        );
      }
    });

    test('gradient stop offsets are bounded 0..1 on backgrounds and decorations', () {
      for (final kind in const ['gradient', 'radial']) {
        final stops = _map(_map(_variant('background', 'kind', kind)['properties'])['stops']);
        expect(stops['type'], 'array', reason: '$kind stops are an array');
        expect(_map(stops['items'])['type'], 'number');
        expect(_map(stops['items'])['minimum'], 0);
        expect(_map(stops['items'])['maximum'], 1);
      }
      final gradient = _map(_map(_map(_defs()['decoration'])['properties'])['gradient']);
      final stops = _map(_map(gradient['properties'])['stops']);
      expect(stops['type'], 'array');
      expect(_map(stops['items'])['minimum'], 0);
      expect(_map(stops['items'])['maximum'], 1);
    });

    test('a step entry is closed over elements and notes and requires elements', () {
      final step = _map(_defs()['stepEntry']);
      expect(step['additionalProperties'], isFalse);
      expect(_list(step['required']), ['elements']);
      expect(_map(step['properties']).keys.toSet(), {'elements', 'notes'});
      expect(_map(_map(step['properties'])['elements'])['minItems'], 1);
    });

    test('the notes def is closed over text and highlights', () {
      final notes = _map(_defs()['notes']);
      expect(notes['additionalProperties'], isFalse);
      expect(_map(notes['properties']).keys.toSet(), {'text', 'highlights'});
    });

    test('a scene refs the step and notes defs', () {
      final properties = _map(_map(_defs()['scene'])['properties']);
      expect(_map(_map(properties['steps'])['items'])[r'$ref'], r'#/$defs/stepEntry');
      expect(_map(properties['notes'])[r'$ref'], r'#/$defs/notes');
    });

    test('Box size is documented as a 0..1 fraction, not pixels', () {
      final size = _map(_defs()['size']);
      expect(_map(_map(size['properties'])['width'])['maximum'], 1);
      expect(size['description']! as String, contains('fraction'));
    });

    test('the text span def is closed over text, style, and link', () {
      final span = _map(_defs()['textSpan']);
      expect(span['additionalProperties'], isFalse);
      expect(_list(span['required']), ['text']);
      expect(_map(span['properties']).keys.toSet(), {'text', 'style', 'link'});
    });

    test('the text style allows bold, normal and the named weights', () {
      final fontWeight = _map(_map(_map(_defs()['textStyle'])['properties'])['fontWeight']);
      final weights = _list(fontWeight['enum']).cast<String>();
      expect(weights, containsAll(<String>['normal', 'bold', 'w100', 'w700', 'w900']));
    });

    test('a media source names the four kinds, the bundle kind included', () {
      final source = _map(_defs()['imageSource']);
      final kinds = _list(_map(_map(source['properties'])['kind'])['enum']).cast<String>();
      expect(kinds, ['asset', 'network', 'file', 'bundle']);
    });

    test('the masters block maps identifier names to the master def', () {
      final masters = _map(_map(videoSpecSchema['properties'])['masters']);
      expect(_map(masters['propertyNames'])['pattern'], r'^[a-zA-Z][a-zA-Z0-9]*$');
      expect(_map(masters['additionalProperties'])[r'$ref'], r'#/$defs/master');
    });

    test('the master def is closed over exactly the keys MasterSpec reads', () {
      final master = _map(_defs()['master']);
      expect(master['additionalProperties'], isFalse);
      expect(_map(master['properties']).keys.toSet(), MasterSpec.knownKeys);
      expect(
        _map(_map(_map(master['properties'])['children'])['items'])[r'$ref'],
        r'#/$defs/masterElement',
      );
    });

    test('the placeholder def is closed and requires its slot', () {
      final placeholder = _map(_defs()['placeholder']);
      expect(placeholder['additionalProperties'], isFalse);
      expect(_list(placeholder['required']), ['type', 'slot']);
      expect(_map(_map(placeholder['properties'])['type'])['const'], 'Placeholder');
      expect(_map(placeholder['properties']).keys.toSet(), {'type', 'slot', 'transform', 'style'});
    });

    test('a master child is an identity-free element or a placeholder', () {
      final oneOf = _list(_map(_defs()['masterElement'])['oneOf']);
      expect(oneOf, hasLength(2));
      final element = _list(_map(oneOf[0])['allOf']);
      expect(_map(element[0])[r'$ref'], r'#/$defs/element');
      final forbidden = _list(_map(_map(element[1])['not'])['anyOf']);
      expect(
        [for (final clause in forbidden) _list(_map(clause)['required']).single],
        ['id', 'anchor', 'shared'],
      );
      expect(_map(oneOf[1])[r'$ref'], r'#/$defs/placeholder');
    });

    test('a scene adopts a master by name and fills its slots with elements', () {
      final properties = _map(_map(_defs()['scene'])['properties']);
      expect(_map(properties['master'])['type'], 'string');
      final fills = _map(properties['fills']);
      expect(_map(fills['propertyNames'])['pattern'], r'^[a-zA-Z][a-zA-Z0-9]*$');
      expect(_map(fills['additionalProperties'])[r'$ref'], r'#/$defs/element');
    });
  });
}
