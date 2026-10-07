import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:fluvie_editor/src/inspector/background_editor.dart';
import 'package:fluvie_editor/src/inspector/background_gradient.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiThemeData;

const _scope = TokenColorScope(
  tokens: [NamedColor(name: 'accent', color: Color(0xFF6C5CE7))],
);

void main() {
  group('gradientValueOf', () {
    test('spaces the colors evenly and defaults the angle to 45', () {
      final value = gradientValueOf(const {
        'kind': 'gradient',
        'colors': ['#FF101018', '#FF2D3436', '#FF00FF00'],
      }, _scope);
      expect([for (final stop in value.stops) stop.offset], [0, 0.5, 1]);
      expect(value.stops.first.color, const Color(0xFF101018));
      expect(value.kind, GradientEditorKind.linear);
      expect(value.angle, 45);
    });

    test('derives the angle from begin and end and resolves tokens', () {
      final value = gradientValueOf(const {
        'kind': 'gradient',
        'colors': [
          {'token': 'accent'},
          '#FFFFFFFF',
        ],
        'begin': 'topCenter',
        'end': 'bottomCenter',
      }, _scope);
      expect(value.angle, 90);
      expect(value.stops.first.color, const Color(0xFF6C5CE7));
    });

    test('reads radial as the radial kind', () {
      final value = gradientValueOf(const {
        'kind': 'radial',
        'colors': ['#FF101018', '#FF2D3436'],
      }, _scope);
      expect(value.kind, GradientEditorKind.radial);
    });

    test('reads explicit stop offsets when the background carries them', () {
      final value = gradientValueOf(const {
        'kind': 'gradient',
        'colors': ['#FF101018', '#FF2D3436', '#FF00FF00'],
        'stops': [0, 0.15, 1],
      }, _scope);
      expect([for (final stop in value.stops) stop.offset], [0, 0.15, 1]);
    });

    test('falls back to even spacing when the stops list does not line up', () {
      final value = gradientValueOf(const {
        'kind': 'gradient',
        'colors': ['#FF101018', '#FF2D3436', '#FF00FF00'],
        'stops': [0, 1],
      }, _scope);
      expect([for (final stop in value.stops) stop.offset], [0, 0.5, 1]);
    });
  });

  group('gradientBackgroundJson', () {
    const previous = <String, Object?>{
      'kind': 'gradient',
      'colors': [
        {'token': 'accent'},
        '#FFFFFFFF',
      ],
    };

    test('writes evenly spaced colors and the angle as begin and end', () {
      final json = gradientBackgroundJson(
        const GradientEditorValue(
          stops: [
            GradientEditorStop(offset: 0, color: Color(0xFF101018)),
            GradientEditorStop(offset: 1, color: Color(0xFF00FF00)),
          ],
          angle: 90,
        ),
        const {'kind': 'gradient'},
        _scope,
      );
      expect(json, {
        'kind': 'gradient',
        'colors': ['#FF101018', '#FF00FF00'],
        'begin': 'topCenter',
        'end': 'bottomCenter',
      });
    });

    test('an unchanged stop keeps its raw token reference', () {
      final json = gradientBackgroundJson(
        const GradientEditorValue(
          stops: [
            GradientEditorStop(offset: 0, color: Color(0xFF6C5CE7)),
            GradientEditorStop(offset: 1, color: Color(0xFF00FF00)),
          ],
        ),
        previous,
        _scope,
      );
      expect(json['colors'], [
        {'token': 'accent'},
        '#FF00FF00',
      ]);
    });

    test('radial writes no begin or end', () {
      final json = gradientBackgroundJson(
        const GradientEditorValue(
          stops: [
            GradientEditorStop(offset: 0, color: Color(0xFF101018)),
            GradientEditorStop(offset: 1, color: Color(0xFF00FF00)),
          ],
          kind: GradientEditorKind.radial,
        ),
        previous,
        _scope,
      );
      expect(json['kind'], 'radial');
      expect(json.containsKey('begin'), isFalse);
      expect(json.containsKey('end'), isFalse);
    });

    test('skewed offsets write the full stops list', () {
      final json = gradientBackgroundJson(
        const GradientEditorValue(
          stops: [
            GradientEditorStop(offset: 0, color: Color(0xFF101018)),
            GradientEditorStop(offset: 0.15, color: Color(0xFFFF0000)),
            GradientEditorStop(offset: 1, color: Color(0xFF00FF00)),
          ],
          angle: 90,
        ),
        const {'kind': 'gradient'},
        _scope,
      );
      expect(json['stops'], [0, 0.15, 1]);
    });

    test('even offsets elide the stops key (the canonical form)', () {
      final json = gradientBackgroundJson(
        const GradientEditorValue(
          stops: [
            GradientEditorStop(offset: 0, color: Color(0xFF101018)),
            GradientEditorStop(offset: 0.5, color: Color(0xFFFF0000)),
            GradientEditorStop(offset: 1, color: Color(0xFF00FF00)),
          ],
          angle: 90,
        ),
        const {
          'kind': 'gradient',
          'stops': [0, 0.15, 1],
        },
        _scope,
      );
      expect(
        json.containsKey('stops'),
        isFalse,
        reason: 'dragging back to even spacing removes the stale list',
      );
    });

    test('unchanged offsets keep the raw stops list verbatim', () {
      const raw = [0, 0.15, 1];
      final json = gradientBackgroundJson(
        const GradientEditorValue(
          stops: [
            GradientEditorStop(offset: 0, color: Color(0xFF101018)),
            GradientEditorStop(offset: 0.15, color: Color(0xFFFF0000)),
            GradientEditorStop(offset: 1, color: Color(0xFF00FF00)),
          ],
          angle: 90,
        ),
        const {
          'kind': 'gradient',
          'stops': raw,
        },
        _scope,
      );
      expect(identical(json['stops'], raw), isTrue, reason: 'integer zero must not become 0.0');
    });

    test('a non-cardinal angle writes fractional alignments that read back', () {
      final json = gradientBackgroundJson(
        const GradientEditorValue(
          stops: [
            GradientEditorStop(offset: 0, color: Color(0xFF101018)),
            GradientEditorStop(offset: 1, color: Color(0xFF00FF00)),
          ],
          angle: 30,
        ),
        const {'kind': 'gradient'},
        _scope,
      );
      final read = gradientValueOf(json, _scope);
      expect(read.angle, closeTo(30, 0.1));
    });
  });

  group('the background editor wires the gradient editor', () {
    Future<List<Map<String, Object?>?>> pump(
      WidgetTester tester,
      Map<String, Object?> background,
    ) async {
      var current = background;
      final patches = <Map<String, Object?>?>[];
      await tester.pumpWidget(
        OiApp(
          title: 'test',
          theme: OiThemeData.dark(),
          home: Center(
            child: SizedBox(
              width: 260,
              child: SingleChildScrollView(
                child: StatefulBuilder(
                  builder: (context, setState) => BackgroundEditor(
                    background: current,
                    colors: _scope,
                    onPatch: (next, {mergeGroup}) {
                      patches.add(next);
                      setState(() => current = next!);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return patches;
    }

    testWidgets('tapping the middle of the stops bar adds a color without stops', (tester) async {
      final patches = await pump(tester, const {
        'kind': 'gradient',
        'colors': ['#FF101018', '#FF2D3436'],
      });
      final bar = tester.getRect(find.byKey(const ValueKey('gradient-stops-bar')));
      await tester.tapAt(Offset(bar.left + 8 + (bar.width - 16) * 0.5, bar.center.dy));
      await tester.pump();
      expect(patches.single!['colors']! as List, hasLength(3));
      expect(
        patches.single!.containsKey('stops'),
        isFalse,
        reason: 'an exactly even result stays in the canonical stops-less form',
      );
    });

    testWidgets('tapping off center writes the skewed stops list', (tester) async {
      final patches = await pump(tester, const {
        'kind': 'gradient',
        'colors': ['#FF101018', '#FF2D3436'],
      });
      final bar = tester.getRect(find.byKey(const ValueKey('gradient-stops-bar')));
      await tester.tapAt(Offset(bar.left + 8 + (bar.width - 16) * 0.75, bar.center.dy));
      await tester.pump();
      final stops = patches.single!['stops']! as List;
      expect(stops, hasLength(3));
      expect(stops[1] as num, closeTo(0.75, 0.03));
    });

    testWidgets('dragging a handle commits its new offset as stops', (tester) async {
      final patches = await pump(tester, const {
        'kind': 'gradient',
        'colors': ['#FF101018', '#FF6C5CE7', '#FF2D3436'],
      });
      final bar = tester.getRect(find.byKey(const ValueKey('gradient-stops-bar')));
      final gesture = await tester.startGesture(
        Offset(bar.left + 8 + (bar.width - 16) * 0.5, bar.center.dy),
      );
      await gesture.moveBy(Offset((bar.width - 16) * 0.25, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      final stops = patches.single!['stops']! as List;
      expect(stops[1] as num, closeTo(0.75, 0.03));
    });

    testWidgets('the selected stop edits through a token-aware color field', (tester) async {
      final patches = await pump(tester, const {
        'kind': 'gradient',
        'colors': ['#FF101018', '#FF2D3436'],
      });
      await tester.tap(find.bySemanticsLabel('Stop color'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Token accent'));
      await tester.pumpAndSettle();
      expect(patches.single!['colors'], [
        {'token': 'accent'},
        '#FF2D3436',
      ]);
    });

    testWidgets('the angle field writes begin and end', (tester) async {
      final patches = await pump(tester, const {
        'kind': 'gradient',
        'colors': ['#FF101018', '#FF2D3436'],
      });
      await tester.enterText(find.byType(EditableText).last, '0');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(patches.single!['begin'], 'centerLeft');
      expect(patches.single!['end'], 'centerRight');
    });
  });
}
