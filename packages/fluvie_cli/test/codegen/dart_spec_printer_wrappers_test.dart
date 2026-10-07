import 'package:fluvie_cli/src/codegen/dart_spec_printer.dart';
import 'package:test/test.dart';

Map<String, Object?> _doc(Map<String, Object?> element) => {
  'fluvieSpec': 1,
  'size': 'hd',
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'children': [element],
    },
  ],
};

void main() {
  group('the wrapper elements print their nested child', () {
    test('Snapshot', () {
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'Snapshot',
            'fit': 'cover',
            'child': {'type': 'Text', 'text': 'frozen'},
          }),
        ),
        allOf(
          contains('Snapshot('),
          contains('fit: BoxFit.cover'),
          contains("child: Text('frozen')"),
        ),
      );
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'Snapshot',
            'child': {'type': 'Text', 'text': 'x'},
          }),
        ),
        isNot(contains('fit:')),
      );
    });

    test('DeviceFrame phone elides its default notch', () {
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'DeviceFrame',
            'variant': 'phone',
            'child': {'type': 'Text', 'text': 'app'},
          }),
        ),
        allOf(contains('DeviceFrame.phone('), isNot(contains('notch:'))),
      );
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'DeviceFrame',
            'variant': 'phone',
            'notch': false,
            'child': {'type': 'Text', 'text': 'app'},
          }),
        ),
        contains('notch: false'),
      );
    });

    test('DeviceFrame browser and tablet', () {
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'DeviceFrame',
            'variant': 'browser',
            'url': 'https://fluvie.dev',
            'child': {'type': 'Markdown', 'source': '# Hi'},
          }),
        ),
        allOf(
          contains('DeviceFrame.browser('),
          contains("url: 'https://fluvie.dev'"),
          contains("child: Markdown('# Hi')"),
        ),
      );
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'DeviceFrame',
            'variant': 'tablet',
            'child': {'type': 'Text', 'text': 'x'},
          }),
        ),
        contains('DeviceFrame.tablet('),
      );
    });

    test('DeviceFrame rejects mismatched chrome like the builder', () {
      expect(
        () => printVideoSpecJson(
          _doc({
            'type': 'DeviceFrame',
            'variant': 'browser',
            'notch': true,
            'child': {'type': 'Text', 'text': 'x'},
          }),
        ),
        throwsFormatException,
      );
      expect(
        () => printVideoSpecJson(
          _doc({
            'type': 'DeviceFrame',
            'variant': 'tablet',
            'url': 'https://x.dev',
            'child': {'type': 'Text', 'text': 'x'},
          }),
        ),
        throwsFormatException,
      );
      expect(
        () => printVideoSpecJson(
          _doc({
            'type': 'DeviceFrame',
            'variant': 'watch',
            'child': {'type': 'Text', 'text': 'x'},
          }),
        ),
        throwsFormatException,
      );
    });

    test('Callout', () {
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'Callout',
            'label': 'Active users',
            'target': {'x': 220, 'y': 130},
            'labelAt': {'x': 24, 'y': 20},
            'color': '#6C5CE7',
            'child': {'type': 'Box', 'color': '#101018'},
          }),
        ),
        allOf(
          contains('Callout('),
          contains("label: 'Active users'"),
          contains('target: Offset(220, 130)'),
          contains('labelAt: Offset(24, 20)'),
          contains('color: Color(0xFF6C5CE7)'),
          contains('child: Box(color: Color(0xFF101018))'),
        ),
      );
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'Callout',
            'label': 'Here',
            'target': {'x': 1, 'y': 2},
            'child': {'type': 'Text', 'text': 'x'},
          }),
        ),
        isNot(contains('labelAt:')),
      );
    });

    test('Spotlight', () {
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'Spotlight',
            'region': {'x': 40, 'y': 30, 'w': 180, 'h': 120},
            'reveal': '18f',
            'color': '#CC000000',
            'child': {
              'type': 'Image',
              'source': {'kind': 'asset', 'value': 'dashboard.png'},
            },
          }),
        ),
        allOf(
          contains('Spotlight.on('),
          contains('region: Rect.fromLTWH(40, 30, 180, 120)'),
          contains('reveal: 18.frames'),
          contains('color: Color(0xCC000000)'),
          contains("child: Image.asset('dashboard.png')"),
        ),
      );
    });

    test('LowerThird and TitleCard print their optional child', () {
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'LowerThird',
            'name': 'Ada',
            'child': {'type': 'Box', 'color': '#101018'},
          }),
        ),
        contains('child: Box(color: Color(0xFF101018))'),
      );
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'TitleCard',
            'title': 'One',
            'child': {'type': 'Text', 'text': 'behind'},
          }),
        ),
        contains("child: Text('behind')"),
      );
    });

    test('a child recurses through animate, transform, and its anchors', () {
      final code = printVideoSpecJson(
        _doc({
          'type': 'DeviceFrame',
          'variant': 'browser',
          'child': {
            'type': 'Markdown',
            'source': '# Hi',
            'anchor': 'inner',
            'transform': {'x': 0.5, 'y': 0.5},
            'animate': [
              {'preset': 'fadeIn'},
            ],
          },
        }),
      );
      expect(code, contains("final inner = Anchor('inner');"));
      expect(code, contains('child: Placed('));
      expect(code, contains('.animate([Animation.fadeIn()], anchor: inner)'));
    });
  });
}
