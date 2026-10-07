import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show introspectTimeline;
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart';

EditorDocument document() => EditorDocument.fromJson(const {
  'fluvieSpec': 1,
  'size': {'width': 640, 'height': 360},
  'fps': 30,
  'theme': {
    'palette': {'titleAccent': '#FF0000', 'existing': '#001122'},
  },
  'lanes': [
    {'id': 'titles', 'name': 'Titles', 'kind': 'video'},
  ],
  'scenes': [
    {
      'duration': '120f',
      'children': [
        {'type': 'Text', 'text': 'Existing', 'id': 'old'},
      ],
    },
  ],
});
List<TitleTemplate> fixtures() => [
  for (final file in Directory('assets/titles').listSync().whereType<File>())
    TitleTemplate.fromJson(jsonDecode(file.readAsStringSync()) as Map<String, Object?>),
];
void main() {
  test('each title inserts bounded at the playhead, merges dependencies and undoes atomically', () {
    for (final template in fixtures()) {
      final history = DocumentHistory(document());
      final before = history.document.toJson();
      final prepared = template.prepare(history.document, 0, 100, lane: 'titles');
      history.dispatch(InsertTitleCommand(scene: 0, title: prepared));
      for (final child in (prepared['children']! as List<Object?>).cast<Map<String, Object?>>()) {
        final inserted = history.document.elementJson(child['id']! as String)!;
        expect(inserted['show'], {'from': '100f', 'to': '120f'});
        expect(inserted['lane'], 'titles');
      }
      expect(history.document.themeJson!['palette'], containsPair('titleAccent', '#FF0000'));
      expect(history.document.themeJson!['typeScale'], contains('titleHeadline'));
      final reopened = EditorDocument.fromJson(history.document.toJson());
      expect(reopened.renderDigest, history.document.renderDigest);
      expect(reopened.spec.build(), isNotNull);
      history.undo();
      expect(history.document.toJson(), before);
      expect(history.canUndo, isFalse);
    }
  });
  test('existing title tokens and masters are unchanged by an insertion', () {
    final title = fixtures().first;
    final before = document().updateVideo({
      'theme': title.json['theme'],
      'masters': <String, Object?>{},
    });
    final after = InsertTitleCommand(scene: 0, title: title.prepare(before, 0, 0)).apply(before);
    expect(after.themeJson, before.themeJson);
    expect(after.toJson()['masters'], before.toJson()['masters']);
  });
  test('editing a spring curve keeps its resolved duration and remains one undo', () {
    final initial = document().addAnimation('old', {'preset': 'fadeIn', 'spring': 'gentle'});
    final before = introspectTimeline(
      initial.spec.build(),
    ).elementById('old')!.animations.single.span.durationFrames;
    final history = DocumentHistory(initial)
      ..dispatch(
        const SetAnimationEaseCommand(
          id: 'old',
          index: 0,
          ease: {
            'cubic': [0.2, 0.9, 0.6, 1],
          },
        ),
      );
    final animation = (history.document.elementJson('old')!['animate']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .single;
    expect(animation['spring'], isNull);
    expect(animation['duration'], '${before}f');
    history.undo();
    expect(history.document.renderDigest, initial.renderDigest);
  });
  testWidgets('title browser inserts and selects editable text', (tester) async {
    final history = DocumentHistory(document());
    Set<String>? selected;
    await tester.pumpWidget(
      OiApp(
        title: 'Titles',
        theme: OiThemeData.dark(),
        home: TitlesPanel(
          document: history.document,
          scene: 0,
          frame: 12,
          onCommand: history.dispatch,
          catalog: Future.value(fixtures()),
          onInserted: (ids) => selected = ids,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).first, 'Full-screen');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Full-screen headline'));
    await tester.tap(find.text('Full-screen headline'));
    await tester.pumpAndSettle();
    expect(history.document.elementJson(selected!.single)!['type'], 'SplitText');
    expect(history.document.elementJson(selected!.single)!['show'], {'from': '12f', 'to': '102f'});
    expect(tester.takeException(), isNull);
  });
  testWidgets('curve drag commits once, persists cubic and undoes with the document', (
    tester,
  ) async {
    final history = DocumentHistory(
      document().addAnimation('old', {'preset': 'fadeIn', 'duration': '30f', 'ease': 'linear'}),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(selectionProvider.notifier).select({'old'});
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: OiApp(
          title: 'Motion',
          theme: OiThemeData.dark(),
          home: ListenableBuilder(
            listenable: history,
            builder: (_, _) =>
                AnimationPanel(document: history.document, onCommand: history.dispatch),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final plot = find.byKey(const ValueKey('easing-curve-plot'));
    await tester.ensureVisible(plot);
    final rect = tester.getRect(plot);
    final gesture = await tester.startGesture(Offset(rect.left + 2, rect.bottom - 2));
    await gesture.moveBy(const Offset(40, -20));
    await tester.pump();
    expect(history.canUndo, isFalse);
    await gesture.moveBy(const Offset(20, -25));
    await gesture.up();
    await tester.pumpAndSettle();
    final ease = (history.document.elementJson('old')!['animate']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .single['ease'];
    expect(ease, isA<Map<String, Object?>>());
    expect(
      EditorDocument.fromJson(history.document.toJson()).renderDigest,
      history.document.renderDigest,
    );
    history.undo();
    expect(
      (history.document.elementJson('old')!['animate']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .single['ease'],
      'linear',
    );
    expect(history.canUndo, isFalse);
    expect(tester.takeException(), isNull);
  });
}
