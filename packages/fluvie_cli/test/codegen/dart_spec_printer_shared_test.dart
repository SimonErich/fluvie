import 'package:fluvie_cli/src/codegen/dart_spec_printer.dart';
import 'package:test/test.dart';

Map<String, Object?> _doc(List<Map<String, Object?>> scenes) => {
  'fluvieSpec': 1,
  'size': 'hd',
  'fps': 30,
  'scenes': scenes,
};

Map<String, Object?> _scene(Map<String, Object?> element) => {
  'duration': '60f',
  'children': [element],
};

void main() {
  group('shared ids print the hero pairing', () {
    test('a widget with a shared parameter takes the declared anchor variable', () {
      final code = printVideoSpecJson(
        _doc([
          _scene({'type': 'Box', 'color': '#6C5CE7', 'shared': 'logo'}),
        ]),
      );
      expect(code, contains("final logo = Anchor('logo');"));
      expect(code, contains('Box(color: Color(0xFF6C5CE7), shared: logo)'));
    });

    test('an argument-less constructor still gains the parameter cleanly', () {
      expect(
        printVideoSpecJson(
          _doc([
            _scene({'type': 'Bars', 'shared': 'spectrum'}),
          ]),
        ),
        contains('Bars(shared: spectrum)'),
      );
    });

    test('a Text (no shared parameter) wraps in the public SharedElement', () {
      final code = printVideoSpecJson(
        _doc([
          _scene({'type': 'Text', 'text': 'hero', 'shared': 'headline'}),
        ]),
      );
      expect(code, contains("final headline = Anchor('headline');"));
      expect(code, contains("SharedElement(anchor: headline, child: Text('hero'))"));
    });

    test('the shared wrap sits inside animate, mirroring the builder', () {
      final code = printVideoSpecJson(
        _doc([
          _scene({
            'type': 'Box',
            'color': '#6C5CE7',
            'shared': 'logo',
            'anchor': 'intro',
            'animate': [
              {'preset': 'fadeIn'},
            ],
          }),
        ]),
      );
      expect(code, contains('shared: logo'));
      expect(code, contains('.animate([Animation.fadeIn()], anchor: intro)'));
      expect(
        code.indexOf('shared: logo'),
        lessThan(code.indexOf('.animate(')),
        reason: 'the shared parameter rides the constructor the animate wraps',
      );
    });

    test('two scenes naming the same id declare ONE anchor variable', () {
      final code = printVideoSpecJson(
        _doc([
          _scene({'type': 'Box', 'color': '#6C5CE7', 'shared': 'logo'}),
          _scene({'type': 'Box', 'color': '#6C5CE7', 'shared': 'logo'}),
        ]),
      );
      expect("final logo = Anchor('logo');".allMatches(code), hasLength(1));
      expect('shared: logo'.allMatches(code), hasLength(2));
    });

    test('a shared id inside a wrapper child is declared too', () {
      final code = printVideoSpecJson(
        _doc([
          _scene({
            'type': 'DeviceFrame',
            'variant': 'tablet',
            'child': {
              'type': 'Image',
              'source': {'kind': 'asset', 'value': 'a.png'},
              'shared': 'photo',
            },
          }),
        ]),
      );
      expect(code, contains("final photo = Anchor('photo');"));
      expect(code, contains('shared: photo'));
    });
  });
}
