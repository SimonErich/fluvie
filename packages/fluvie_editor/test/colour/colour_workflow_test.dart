import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:fluvie_editor/src/colour/tone_curve_editor.dart';
import 'package:obers_ui/obers_ui.dart';

EditorDocument _document() => EditorDocument.fromJson(const {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'children': [
        {
          'type': 'Box',
          'id': 'a',
          'effects': [
            {'kind': 'grain', 'amount': 0.2},
          ],
        },
        {'type': 'Box', 'id': 'b'},
      ],
    },
  ],
});

void main() {
  test('all looks round-trip at both intensities, preserving unrelated effects and one undo', () {
    for (final look in colourLooks) {
      for (final intensity in [0.6, 1.0]) {
        final history = DocumentHistory(_document());
        final digest = history.document.renderDigest;
        history.dispatch(
          ApplyColourCommand(ids: const ['a', 'b'], effects: look.at(intensity), name: look.name),
        );
        expect(history.document.renderDigest, isNot(digest));
        final reopened = EditorDocument.fromJson(history.document.toJson());
        expect(reopened.renderDigest, history.document.renderDigest);
        expect(
          (reopened.elementJson('a')!['effects']! as List<Object?>)
              .cast<Map<String, Object?>>()
              .first,
          {
            'kind': 'grain',
            'amount': 0.2,
          },
        );
        expect(
          (reopened.elementJson('b')!['effects']! as List<Object?>)
              .cast<Map<String, Object?>>()
              .single['intensity'],
          intensity,
        );
        history.undo();
        expect(history.document.renderDigest, digest);
      }
    }
  });

  testWidgets('Colour workspace applies a look, edits curves and imports a portable LUT', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final history = DocumentHistory(_document());
    container.read(selectionProvider.notifier).select({'a'});
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: OiApp(
          title: 'Colour',
          theme: OiThemeData.dark(),
          home: ListenableBuilder(
            listenable: history,
            builder: (context, _) => SizedBox(
              width: 350,
              child: ColourPanel(
                document: history.document,
                onCommand: history.dispatch,
                onImportLut: () async => colourLooks.last.effects.single['cube']! as String,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('look-Social')));
    await tester.pumpAndSettle();
    expect(
      (history.document.elementJson('a')!['effects']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .last['intensity'],
      0.6,
    );
    await tester.tap(find.text('Add curves'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add point'));
    await tester.tap(find.text('Add point'));
    await tester.pumpAndSettle();
    final curve = (history.document.elementJson('a')!['effects']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .last;
    expect((curve['curves']! as Map<String, Object?>)['master'], hasLength(3));
    expect(find.byType(ToneCurveEditor), findsOneWidget);
    await tester.ensureVisible(find.text('Import .cube LUT'));
    await tester.tap(find.text('Import .cube LUT'));
    await tester.pumpAndSettle();
    expect(
      (history.document.elementJson('a')!['effects']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .last['cube'],
      contains('LUT_3D_SIZE'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('malformed LUT is shown and cannot alter the document', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(selectionProvider.notifier).select({'a'});
    var dispatched = false;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: OiApp(
          title: 'Colour',
          theme: OiThemeData.dark(),
          home: ColourPanel(
            document: _document(),
            onCommand: (_) => dispatched = true,
            onImportLut: () async => 'invalid',
          ),
        ),
      ),
    );
    await tester.tap(find.text('Import .cube LUT'));
    await tester.pumpAndSettle();
    expect(dispatched, isFalse);
    expect(find.textContaining('LUT import failed'), findsOneWidget);
  });
}
