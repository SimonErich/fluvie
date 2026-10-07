import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show introspectTimeline;
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiSelect, OiThemeData;

const _palette = TimelinePhasePalette(
  enter: Color(0xFF46A758),
  during: Color(0xFFFFB224),
  exit: Color(0xFFE5484D),
);
const _links = TimelineLinkPalette(ends: Color(0xFF0000FF), starts: Color(0xFF00FFFF));

Map<String, Object?> _deck({bool hidden = false}) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '120f',
      'children': [
        {
          'id': 'el-k',
          'type': 'Box',
          'width': 80,
          'height': 40,
          if (hidden) 'visible': false,
          'animate': [
            {
              'keyframes': [
                {'opacity': 0},
                <String, Object?>{},
              ],
              'duration': '30f',
            },
            {'preset': 'fadeOut', 'duration': '20f'},
          ],
        },
      ],
    },
  ],
};

final class _Harness {
  _Harness(this.container, this.history);
  final ProviderContainer container;
  final DocumentHistory history;
}

Future<_Harness> _pump(WidgetTester tester, {bool hidden = false}) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final history = DocumentHistory(EditorDocument.fromJson(_deck(hidden: hidden)));
  container.read(selectionProvider.notifier).select({'el-k'});
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: OiApp(
        title: 'test',
        theme: OiThemeData.dark(),
        home: ListenableBuilder(
          listenable: history,
          builder: (context, _) => Row(
            children: [
              const Spacer(),
              SizedBox(
                width: 280,
                child: EditorInspector(
                  document: history.document,
                  slide: 0,
                  onCommand: history.dispatch,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return _Harness(container, history);
}

List<Map<String, Object?>> _animate(EditorDocument document) =>
    (document.elementJson('el-k')!['animate']! as List).cast<Map<String, Object?>>();

void _pick(WidgetTester tester, Key key, String value) =>
    tester.widget<OiSelect<String>>(find.byKey(key)).onChanged!(value);

Finder _field(int index) => find.byType(EditableText).at(index);

void main() {
  testWidgets('the panel lists every animation by name with its phase color', (tester) async {
    await _pump(tester);
    expect(find.text('Animate'), findsOneWidget);
    expect(find.text('keyframes'), findsOneWidget);
    expect(find.text('fadeOut'), findsOneWidget);
  });

  testWidgets('the duration field shows resolved frames and trims undoably', (tester) async {
    final harness = await _pump(tester);
    expect(tester.widget<EditableText>(_field(0)).controller.text, '30');
    await tester.enterText(_field(0), '18');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(_animate(harness.history.document)[0]['duration'], '18f');
    harness.history.undo();
    expect(_animate(harness.history.document)[0]['duration'], '30f');
  });

  testWidgets('the ease select writes the named ease and inherit clears it', (tester) async {
    final harness = await _pump(tester);
    _pick(tester, const ValueKey('animate-ease-1'), 'snappy');
    await tester.pump();
    expect(_animate(harness.history.document)[1]['ease'], 'snappy');
    _pick(tester, const ValueKey('animate-ease-1'), 'inherit');
    await tester.pump();
    expect(_animate(harness.history.document)[1].containsKey('ease'), isFalse);
  });

  testWidgets('the trigger select writes the simple forms and auto clears', (tester) async {
    final harness = await _pump(tester);
    _pick(tester, const ValueKey('animate-trigger-1'), 'previous');
    await tester.pump();
    expect(_animate(harness.history.document)[1]['at'], 'previous');
    _pick(tester, const ValueKey('animate-trigger-1'), 'auto');
    await tester.pump();
    expect(_animate(harness.history.document)[1].containsKey('at'), isFalse);
  });

  testWidgets('remove drops one animation undoably', (tester) async {
    final harness = await _pump(tester);
    await tester.tap(find.bySemanticsLabel('Remove animation').at(1));
    await tester.pump();
    expect(_animate(harness.history.document), hasLength(1));
    expect(_animate(harness.history.document).single.containsKey('keyframes'), isTrue);
    harness.history.undo();
    expect(_animate(harness.history.document), hasLength(2));
  });

  testWidgets('adding a preset writes the same bar the timeline model renders', (tester) async {
    final harness = await _pump(tester);
    _pick(tester, const ValueKey('animate-add'), 'pop');
    await tester.pump();
    expect(_animate(harness.history.document).last, {'preset': 'pop'});

    // One document truth: the timeline model now renders exactly that bar.
    final model = SlideTimelineModel.build(
      document: harness.history.document,
      slide: 0,
      palette: _palette,
      linkPalette: _links,
    );
    final bar = model.tracks.single.bars.last;
    expect(bar.badge, 'pop');
    expect(bar.color, _palette.enter);
    final scene = introspectTimeline(harness.history.document.spec.build()).scenes[0];
    final span = scene.elementById('el-k')!.animations.last.span;
    expect(bar.start, span.start.toDouble());
    expect(bar.end, span.end.toDouble());
    // And the panel's own duration field reads the same resolved frames
    // (each animation row carries a length and an offset field).
    final binding = model.bindings[bar.id]!;
    expect(
      tester.widget<EditableText>(_field(4)).controller.text,
      '${binding.durationFrames}',
    );
  });

  testWidgets('a hidden element lists its animations without resolved timing', (tester) async {
    // `visible: false` builds nothing, so introspection has no spans to
    // resolve — the rows keep name, ease, trigger, and remove, but carry no
    // duration field.
    final harness = await _pump(tester, hidden: true);
    expect(find.text('keyframes'), findsOneWidget);
    expect(find.text('fadeOut'), findsOneWidget);
    expect(find.byType(EditableText), findsNothing);
    await tester.tap(find.bySemanticsLabel('Remove animation').at(1));
    await tester.pump();
    expect(_animate(harness.history.document), hasLength(1));
  });

  testWidgets('the add picker also starts a two-stop keyframes animation', (tester) async {
    final harness = await _pump(tester);
    _pick(tester, const ValueKey('animate-add'), 'keyframes');
    await tester.pump();
    expect(_animate(harness.history.document).last, {
      'keyframes': [<String, Object?>{}, <String, Object?>{}],
    });
  });
}
