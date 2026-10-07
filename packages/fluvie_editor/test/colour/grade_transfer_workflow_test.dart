import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart';

import '../commands/fake_system_clipboard.dart';

void main() {
  testWidgets('copy and paste grade targets selection or picture lane atomically', (tester) async {
    final clipboard = FakeSystemClipboard()..install();
    addTearDown(clipboard.uninstall);
    final history = DocumentHistory(
      EditorDocument.fromJson({
        'fluvieSpec': 1,
        'lanes': const [
          {'id': 'picture', 'kind': 'video'},
          {'id': 'other', 'kind': 'video'},
        ],
        'scenes': [
          {
            'duration': '60f',
            'children': [
              for (final id in ['a', 'b', 'c'])
                {
                  'id': id,
                  'type': 'Clip',
                  'source': {'kind': 'file', 'value': '$id.mp4'},
                  'lane': id == 'c' ? 'other' : 'picture',
                  'effects': [
                    {'kind': 'grain', 'amount': .2},
                  ],
                },
              const {'id': 'box', 'type': 'Box'},
            ],
          },
        ],
      }),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    addTearDown(history.dispose);
    await container.read(editorClipboardProvider).write(const ClipboardEnvelope.effects([]));
    container.read(selectionProvider.notifier).select({'a'});
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: OiApp(
          home: ListenableBuilder(
            listenable: history,
            builder: (_, _) => ColourPanel(document: history.document, onCommand: history.dispatch),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Paste grade'));
    await tester.pumpAndSettle();
    expect(find.text('Copy a grade first.'), findsOneWidget);
    expect(history.canUndo, isFalse);
    tester.widget<MathNumberInput>(find.byKey(const ValueKey('look-intensity'))).onChanged(.85);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('look-Social')));
    await tester.pumpAndSettle();
    List<Map<String, Object?>> effects(String id) =>
        (history.document.elementJson(id)!['effects']! as List<Object?>)
            .cast<Map<String, Object?>>();
    expect(effects('a').last['intensity'], .85);
    await tester.tap(find.text('Copy grade'));
    await tester.pumpAndSettle();
    expect(find.text('Grade copied.'), findsOneWidget);
    await tester.tap(find.text('Paste to lane'));
    await tester.pumpAndSettle();
    expect(effects('b'), effects('a'));
    expect(effects('c'), [
      {'kind': 'grain', 'amount': .2},
    ]);
    expect(find.text('Grade applied to 2 elements.'), findsOneWidget);
    history.undo();
    await tester.pumpAndSettle();
    expect(effects('b'), hasLength(1));
    container.read(selectionProvider.notifier).select({'b', 'c'});
    await tester.pumpAndSettle();
    expect(find.textContaining('2 elements selected'), findsOneWidget);
    await tester.tap(find.text('Paste grade'));
    await tester.pumpAndSettle();
    expect(effects('c'), effects('a'));
    container.read(selectionProvider.notifier).select({'box'});
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paste to lane'));
    await tester.pumpAndSettle();
    expect(effects('box'), [effects('a').last]);
    await tester.tap(find.text('Add correction'));
    await tester.pumpAndSettle();
    expect(effects('box').last, {'kind': 'grade'});
    expect(tester.takeException(), isNull);
  });
}
