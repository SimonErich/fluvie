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

    test('every element type is a closed variant over its known props', () {
      const reserved = {'type', 'anchor', 'animate'};
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

    test('Box size is documented as a 0..1 fraction, not pixels', () {
      final size = _map(_defs()['size']);
      expect(_map(_map(size['properties'])['width'])['maximum'], 1);
      expect(size['description']! as String, contains('fraction'));
    });

    test('the text style allows bold, normal and the named weights', () {
      final fontWeight = _map(_map(_map(_defs()['textStyle'])['properties'])['fontWeight']);
      final weights = _list(fontWeight['enum']).cast<String>();
      expect(weights, containsAll(<String>['normal', 'bold', 'w100', 'w700', 'w900']));
    });
  });
}
