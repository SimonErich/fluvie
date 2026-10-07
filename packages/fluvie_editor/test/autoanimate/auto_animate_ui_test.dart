import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show LivePlayer, Video;
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiSelect, OiSwitch, OiThemeData;

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'layout': 'canvas',
      'children': [
        {
          'id': 'el-title',
          'type': 'Text',
          'text': 'Fluvie',
          'transform': {'x': 0.5, 'y': 0.5, 'w': 0.8, 'h': 0.2},
        },
        {
          'id': 'el-old',
          'type': 'Text',
          'text': 'Only here',
          'transform': {'x': 0.5, 'y': 0.1, 'w': 0.8, 'h': 0.1},
        },
      ],
    },
    {
      'duration': '60f',
      'layout': 'canvas',
      'children': [
        {
          'id': 'el-title-2',
          'type': 'Text',
          'text': 'Fluvie',
          'transform': {'x': 0.3, 'y': 0.12, 'w': 0.5, 'h': 0.1},
        },
        {
          'id': 'el-new',
          'type': 'Box',
          'color': '#00B894',
          'transform': {'x': 0.7, 'y': 0.7, 'w': 0.2, 'h': 0.2},
        },
      ],
    },
  ],
};

final class _Harness {
  _Harness(this.history, this.commands);
  final DocumentHistory history;
  final List<EditorCommand> commands;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  required Widget Function(DocumentHistory history, void Function(EditorCommand) dispatch) child,
  Map<String, Object?>? deck,
  bool autoAnimated = false,
  String? selected,
}) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  var document = EditorDocument.fromJson(deck ?? _deck());
  if (autoAnimated) document = document.applyAutoAnimate(1);
  final history = DocumentHistory(document);
  final commands = <EditorCommand>[];
  if (selected != null) container.read(selectionProvider.notifier).select({selected});
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: OiApp(
        title: 'test',
        theme: OiThemeData.dark(),
        home: ListenableBuilder(
          listenable: history,
          builder: (context, _) => Center(
            child: SizedBox(
              width: 280,
              height: 560,
              child: child(history, (command) {
                commands.add(command);
                history.dispatch(command);
              }),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return _Harness(history, commands);
}

Widget _section(DocumentHistory history, void Function(EditorCommand) dispatch, {int slide = 1}) =>
    AutoAnimateSection(document: history.document, slide: slide, onCommand: dispatch);

void main() {
  group('AutoAnimateSection', () {
    testWidgets('the switch turns auto-animate on', (tester) async {
      final harness = await _pump(tester, child: _section);
      final toggle = tester.widget<OiSwitch>(find.byKey(const ValueKey('auto-animate-switch')));
      expect(toggle.value, isFalse);
      toggle.onChanged!(true);
      await tester.pump();
      expect(harness.commands.single, isA<ApplyAutoAnimateCommand>());
      expect(harness.history.document.autoAnimateOn(1), isTrue);
      expect(harness.history.document.sharedPartnerOf(1, 'el-title-2'), 'el-title');
    });

    testWidgets('the switch turns auto-animate off again', (tester) async {
      final harness = await _pump(tester, autoAnimated: true, child: _section);
      final toggle = tester.widget<OiSwitch>(find.byKey(const ValueKey('auto-animate-switch')));
      expect(toggle.value, isTrue);
      toggle.onChanged!(false);
      await tester.pump();
      final command = harness.commands.single as ApplyAutoAnimateCommand;
      expect(command.enabled, isFalse);
      expect(harness.history.document.autoAnimateOn(1), isFalse);
    });

    testWidgets('an auto-animated slide shows the pair count and actions', (tester) async {
      await _pump(tester, autoAnimated: true, child: _section);
      expect(find.text('1 element morphs from the previous slide'), findsOneWidget);
      expect(find.text('Preview morph'), findsOneWidget);
      expect(find.text('Rematch'), findsOneWidget);
    });

    testWidgets('Rematch re-applies over the current elements', (tester) async {
      final harness = await _pump(tester, autoAnimated: true, child: _section);
      await tester.tap(find.text('Rematch'));
      await tester.pump();
      final command = harness.commands.single as ApplyAutoAnimateCommand;
      expect(command.enabled, isTrue);
    });

    testWidgets('the first slide reads as disabled', (tester) async {
      await _pump(
        tester,
        child: (history, dispatch) => _section(history, dispatch, slide: 0),
      );
      final toggle = tester.widget<OiSwitch>(find.byKey(const ValueKey('auto-animate-switch')));
      expect(toggle.enabled, isFalse);
      expect(find.text('The first slide has nothing to morph from'), findsOneWidget);
    });

    testWidgets('Preview morph opens the boundary player dialog', (tester) async {
      await _pump(tester, autoAnimated: true, child: _section);
      await tester.tap(find.text('Preview morph'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(MorphPreview), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(MorphPreview), findsNothing);
    });

    testWidgets('Escape closes the preview dialog too', (tester) async {
      await _pump(tester, autoAnimated: true, child: _section);
      await tester.tap(find.text('Preview morph'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(MorphPreview), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump();
      expect(find.byType(MorphPreview), findsNothing);
    });

    testWidgets('several pairs read as a plural summary', (tester) async {
      await _pump(
        tester,
        autoAnimated: true,
        child: (history, dispatch) => AutoAnimateSection(
          document: history.document.linkShared(
            slide: 1,
            currentId: 'el-new',
            previousId: 'el-old',
          ),
          slide: 1,
          onCommand: dispatch,
        ),
      );
      expect(find.text('2 elements morph from the previous slide'), findsOneWidget);
    });
  });

  group('MorphSection', () {
    testWidgets('a linked element names its partner and unlinks', (tester) async {
      final harness = await _pump(
        tester,
        autoAnimated: true,
        child: (history, dispatch) => MorphSection(
          document: history.document,
          slide: 1,
          id: 'el-title-2',
          onCommand: dispatch,
        ),
      );
      expect(find.text('Morphs from el-title'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Unlink from the previous slide'));
      await tester.pump();
      expect(harness.commands.single, isA<UnlinkSharedCommand>());
      expect(harness.history.document.sharedPartnerOf(1, 'el-title-2'), isNull);
    });

    testWidgets('a named partner shows its name', (tester) async {
      final deck = _deck();
      deck['editor'] = {
        'editorSchema': 1,
        'elements': {
          'el-title': {'name': 'Headline'},
        },
      };
      await _pump(
        tester,
        deck: deck,
        autoAnimated: true,
        child: (history, dispatch) => MorphSection(
          document: history.document,
          slide: 1,
          id: 'el-title-2',
          onCommand: dispatch,
        ),
      );
      expect(find.text('Morphs from Headline'), findsOneWidget);
    });

    testWidgets('an unlinked element offers the candidate picker', (tester) async {
      final harness = await _pump(
        tester,
        autoAnimated: true,
        child: (history, dispatch) =>
            MorphSection(document: history.document, slide: 1, id: 'el-new', onCommand: dispatch),
      );
      final picker = tester.widget<OiSelect<String>>(
        find.byKey(const ValueKey('morph-link-picker')),
      );
      expect(picker.options.map((option) => option.value), ['el-old']);
      picker.onChanged!('el-old');
      await tester.pump();
      final command = harness.commands.single as LinkSharedCommand;
      expect(command.currentId, 'el-new');
      expect(command.previousId, 'el-old');
      expect(harness.history.document.sharedPartnerOf(1, 'el-new'), 'el-old');
    });

    testWidgets('no candidates reads as not linked', (tester) async {
      final deck = _deck();
      (((deck['scenes']! as List)[0]! as Map<String, Object?>)['children']! as List).removeAt(1);
      await _pump(
        tester,
        deck: deck,
        autoAnimated: true,
        child: (history, dispatch) =>
            MorphSection(document: history.document, slide: 1, id: 'el-new', onCommand: dispatch),
      );
      expect(find.text('No previous slide element to link'), findsOneWidget);
      expect(find.byKey(const ValueKey('morph-link-picker')), findsNothing);
    });
  });

  group('MorphPreview', () {
    testWidgets('plays the boundary from one second before the blend', (tester) async {
      await _pump(
        tester,
        autoAnimated: true,
        child: (history, dispatch) => MorphPreview(document: history.document, slide: 1),
      );
      final player = tester.widget<LivePlayer>(find.byType(LivePlayer));
      // Scenes are 60f at 30 fps with the auto 500ms (15f) crossFade: the
      // incoming scene starts at frame 45, so the loop leads in at 15.
      expect(player.controller.frame, 15);
      final video = tester.widget<Video>(find.byType(Video));
      expect(video.scenes, hasLength(2));
      await tester.pump(const Duration(milliseconds: 500));
      expect(player.controller.frame, greaterThan(15));
      // Unmount cleanly: the preview owns and disposes its clock.
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('EditorInspector wiring', () {
    Widget inspector(
      DocumentHistory history,
      void Function(EditorCommand) dispatch, {
      int slide = 1,
    }) => EditorInspector(document: history.document, slide: slide, onCommand: dispatch);

    testWidgets('the deck section carries Auto-animate past the first slide', (tester) async {
      await _pump(tester, child: inspector);
      expect(find.text('Auto-animate'), findsOneWidget);
    });

    testWidgets('the first slide has no Auto-animate section', (tester) async {
      await _pump(
        tester,
        child: (history, dispatch) => inspector(history, dispatch, slide: 0),
      );
      expect(find.text('Auto-animate'), findsNothing);
    });

    testWidgets('a selection on an auto-animated slide shows the Morph row', (tester) async {
      await _pump(tester, autoAnimated: true, selected: 'el-title-2', child: inspector);
      expect(find.text('Morph'), findsOneWidget);
      expect(find.text('Morphs from el-title'), findsOneWidget);
    });

    testWidgets('without auto-animate there is no Morph row', (tester) async {
      await _pump(tester, selected: 'el-title-2', child: inspector);
      expect(find.text('Morph'), findsNothing);
    });
  });
}
