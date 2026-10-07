import 'package:fluvie_cli/src/codegen/dart_spec_printer.dart';
import 'package:test/test.dart';

Map<String, Object?> _doc(List<Map<String, Object?>> children) => {
  'fluvieSpec': 1,
  'size': 'hd',
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'layout': 'canvas',
      'children': children,
    },
  ],
};

/// The code with whitespace and trailing commas removed, so assertions
/// survive the formatter's line breaking.
String _dense(String code) =>
    code.replaceAll(RegExp(r'\s'), '').replaceAll(',)', ')').replaceAll(',]', ']');

void main() {
  group('a Group prints the builder composition', () {
    test('SizedBox.expand over a Stack of the printed children', () {
      final code = printVideoSpecJson(
        _doc([
          {
            'type': 'Group',
            'children': [
              {
                'type': 'Box',
                'color': '#6C5CE7',
                'transform': {'x': 0.3, 'y': 0.5, 'w': 0.4, 'h': 0.4},
              },
              {'type': 'Text', 'text': 'inside'},
            ],
          },
        ]),
      );
      expect(
        _dense(code),
        contains(
          'SizedBox.expand(child:Stack(children:['
          'Placed(placement:Placement(x:0.3,y:0.5,width:0.4,height:0.4),'
          'child:Box(color:Color(0xFF6C5CE7))),'
          "Text('inside')"
          ']))',
        ),
      );
    });

    test('a placed group nests the composition inside Placed, children fractions and all', () {
      final code = printVideoSpecJson(
        _doc([
          {
            'type': 'Group',
            'transform': {'x': 0.25, 'y': 0.25, 'w': 0.5, 'h': 0.5},
            'children': [
              {'type': 'Box', 'color': '#2ECC8F'},
            ],
          },
        ]),
      );
      expect(
        _dense(code),
        contains(
          'Placed(placement:Placement(x:0.25,y:0.25,width:0.5,height:0.5),'
          'child:SizedBox.expand(child:Stack(children:[Box(color:Color(0xFF2ECC8F))])))',
        ),
      );
    });

    test('an empty group prints an empty stack', () {
      final code = printVideoSpecJson(
        _doc([
          {'type': 'Group', 'children': <Object?>[]},
        ]),
      );
      expect(_dense(code), contains('SizedBox.expand(child:Stack(children:[]))'));
    });

    test('an anchor declared inside a group child gets its variable', () {
      final code = printVideoSpecJson(
        _doc([
          {
            'type': 'Group',
            'children': [
              {
                'type': 'Box',
                'color': '#6C5CE7',
                'anchor': 'intro',
                'shared': 'logo',
              },
            ],
          },
        ]),
      );
      expect(code, contains("final intro = Anchor('intro');"));
      expect(code, contains("final logo = Anchor('logo');"));
      expect(code, contains('anchor: intro'));
      expect(code, contains('shared: logo'));
    });
  });

  group('hidden elements print as their render: nothing', () {
    test('a hidden scene child is omitted with a comment naming it', () {
      final code = printVideoSpecJson(
        _doc([
          {
            'type': 'Box',
            'id': 'el-2',
            'color': '#FF1B1B',
            'visible': false,
          },
          {'type': 'Text', 'text': 'still here'},
        ]),
      );
      expect(code, contains('// hidden: Box "el-2" omitted from the printed build'));
      expect(code, isNot(contains('0xFFFF1B1B')), reason: 'the hidden constructor never prints');
      expect(code, contains("Text('still here')"));
    });

    test('an id-less hidden element is named by type alone', () {
      final code = printVideoSpecJson(
        _doc([
          {'type': 'Box', 'color': '#FF1B1B', 'visible': false},
          {'type': 'Text', 'text': 'still here'},
        ]),
      );
      expect(code, contains('// hidden: Box omitted from the printed build'));
    });

    test('a scene whose only child is hidden still prints valid code', () {
      final code = printVideoSpecJson(
        _doc([
          {'type': 'Box', 'id': 'el-1', 'color': '#FF1B1B', 'visible': false},
        ]),
      );
      expect(code, contains('// hidden: Box "el-1" omitted from the printed build'));
      expect(code, isNot(contains('Box(')));
    });

    test('a hidden group child is omitted inside the group print', () {
      final code = printVideoSpecJson(
        _doc([
          {
            'type': 'Group',
            'children': [
              {'type': 'Box', 'id': 'el-hid', 'color': '#FF1B1B', 'visible': false},
              {'type': 'Box', 'color': '#2ECC8F'},
            ],
          },
        ]),
      );
      expect(code, contains('// hidden: Box "el-hid" omitted from the printed build'));
      expect(code, isNot(contains('0xFFFF1B1B')));
      expect(_dense(code), contains('Stack(children:['));
      expect(_dense(code), contains('Box(color:Color(0xFF2ECC8F))'));
    });

    test('a hidden wrapper child prints the shrink the builder mounts', () {
      final code = printVideoSpecJson(
        _doc([
          {
            'type': 'DeviceFrame',
            'variant': 'tablet',
            'child': {
              'type': 'Box',
              'id': 'el-hid',
              'color': '#FF1B1B',
              'visible': false,
            },
          },
        ]),
      );
      expect(_dense(code), contains('DeviceFrame.tablet(child:constSizedBox.shrink()'));
      expect(code, contains('hidden: Box "el-hid"'));
      expect(code, isNot(contains('0xFFFF1B1B')));
    });
  });
}
