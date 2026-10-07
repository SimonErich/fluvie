import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show VideoSpec, knownElementTypes, unknownSpecProps;
import 'package:fluvie_editor/fluvie_editor.dart';

void main() {
  const capabilities = SpecCapabilities();

  test('the palette offers exactly what the spec can express', () {
    expect(capabilities.insertableTypes, knownElementTypes);
    expect(capabilities.supports('Text'), isTrue);
    expect(capabilities.supports('Clip'), isTrue);
    expect(capabilities.supports('Hologram'), isFalse);
  });

  test('every default template parses, validates, and saves', () {
    for (final type in capabilities.insertableTypes) {
      final element = capabilities.defaultElementJson(type);
      expect(element['type'], type);
      final document = {
        'fluvieSpec': 1,
        'size': 'hd',
        'fps': 30,
        'scenes': [
          {
            'duration': '60f',
            'layout': 'canvas',
            'children': [element],
          },
        ],
      };
      expect(
        () => VideoSpec.fromJson(document),
        returnsNormally,
        reason: '$type default must parse',
      );
      expect(unknownSpecProps(document), isEmpty, reason: '$type default must validate');
      final spec = VideoSpec.fromJson(document);
      expect(spec.toJson(), document, reason: '$type default must round-trip');
    }
  });

  test('an unknown type has no template', () {
    expect(() => capabilities.defaultElementJson('Hologram'), throwsArgumentError);
  });

  test('a Placeholder is masters-only: never insertable, never templated', () {
    // A Placeholder is a master-child form, not an element type, so it is
    // absent from knownElementTypes — and the palette derives from exactly
    // that set, keeping it out of the scene-insertable surface honestly.
    expect(capabilities.insertableTypes, isNot(contains('Placeholder')));
    expect(capabilities.supports('Placeholder'), isFalse);
    expect(() => capabilities.defaultElementJson('Placeholder'), throwsArgumentError);
  });

  test('content defaults carry a transform; annotations carry geometry', () {
    for (final type in const {'Text', 'Box', 'Image', 'Counter', 'Clip'}) {
      expect(
        capabilities.defaultElementJson(type).containsKey('transform'),
        isTrue,
        reason: '$type default should be gizmo-grabbable on insert',
      );
    }
    // Annotations paint in scene pixels; the shape tool writes their
    // geometry, so their defaults carry points instead of a transform.
    for (final type in const {'Shape', 'Arrow', 'Connector'}) {
      final json = capabilities.defaultElementJson(type);
      expect(json.containsKey('transform'), isFalse);
      expect(json.keys, anyOf(contains('from'), contains('rect')));
    }
  });
}
