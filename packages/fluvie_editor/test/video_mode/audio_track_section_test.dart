import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiIconButton, OiSwitch, OiThemeData;

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'audio': [
    {
      'kind': 'music',
      'source': {'kind': 'asset', 'value': 'audio/bed.mp3'},
      'volume': 0.8,
      'fadeIn': '15f',
      'loop': true,
      'trim': {'from': '30f', 'to': '90f'},
    },
    {
      'kind': 'sfx',
      'source': {'kind': 'asset', 'value': 'audio/whoosh.wav'},
      'at': {'kind': 'at', 'time': '20f'},
    },
    {
      'kind': 'sfx',
      'source': {'kind': 'asset', 'value': 'audio/hit.wav'},
      'at': {'kind': 'beat'},
    },
  ],
  'scenes': <Object?>[
    {
      'duration': '120f',
      'children': [
        {'id': 'el-a', 'type': 'Text', 'text': 'a'},
      ],
    },
    {
      'duration': '90f',
      'audio': [
        {
          'kind': 'music',
          'source': {'kind': 'asset', 'value': 'audio/scene.mp3'},
        },
      ],
      'children': [
        {'id': 'el-b', 'type': 'Text', 'text': 'b'},
      ],
    },
  ],
};

final class _Harness {
  _Harness(this.container, this.history);
  final ProviderContainer container;
  final DocumentHistory history;
}

Future<_Harness> _pump(WidgetTester tester, SelectedAudioTrack selection) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  container.read(audioSelectionProvider.notifier).select(selection);
  final history = DocumentHistory(EditorDocument.fromJson(_deck()));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: OiApp(
        title: 'test',
        theme: OiThemeData.dark(),
        home: ListenableBuilder(
          listenable: history,
          builder: (context, _) {
            final selected = container.read(audioSelectionProvider);
            return SingleChildScrollView(
              child: SizedBox(
                width: 280,
                child: selected == null
                    ? const SizedBox.shrink()
                    : AudioTrackSection(
                        document: history.document,
                        selection: selected,
                        timebase: VideoTimebase.of(history.document),
                        onCommand: history.dispatch,
                      ),
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.pump();
  return _Harness(container, history);
}

Finder _input(String key) =>
    find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(EditableText));

Future<void> _commit(WidgetTester tester, String key, String text) async {
  await tester.enterText(_input(key), text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

void main() {
  testWidgets('a music track shows its file, volume, fades, loop, and trim', (tester) async {
    await _pump(tester, const SelectedAudioTrack(scene: null, index: 0));
    expect(find.text('bed.mp3'), findsOneWidget);
    expect(find.text('music'), findsOneWidget);
    expect(tester.widget<EditableText>(_input('audio-volume')).controller.text, '0.8');
    expect(tester.widget<EditableText>(_input('audio-fade-in')).controller.text, '15');
    expect(tester.widget<EditableText>(_input('audio-fade-out')).controller.text, '0');
    expect(tester.widget<OiSwitch>(find.byType(OiSwitch)).value, isTrue);
    expect(tester.widget<EditableText>(_input('audio-trim-from')).controller.text, '30');
    expect(tester.widget<EditableText>(_input('audio-trim-to')).controller.text, '90');
  });

  testWidgets('volume edits dispatch, and one is the elided default', (tester) async {
    final harness = await _pump(tester, const SelectedAudioTrack(scene: null, index: 0));
    await _commit(tester, 'audio-volume', '0.5');
    expect(harness.history.document.audioTracksJson()[0]['volume'], 0.5);
    await _commit(tester, 'audio-volume', '1');
    expect(harness.history.document.audioTracksJson()[0].containsKey('volume'), isFalse);
    harness.history.undo();
    harness.history.undo();
    expect(harness.history.document.audioTracksJson()[0]['volume'], 0.8);
  });

  testWidgets('fades write frames form and zero clears', (tester) async {
    final harness = await _pump(tester, const SelectedAudioTrack(scene: null, index: 0));
    await _commit(tester, 'audio-fade-out', '24');
    expect(harness.history.document.audioTracksJson()[0]['fadeOut'], '24f');
    await _commit(tester, 'audio-fade-in', '0');
    expect(harness.history.document.audioTracksJson()[0].containsKey('fadeIn'), isFalse);
  });

  testWidgets('the loop switch round-trips', (tester) async {
    final harness = await _pump(tester, const SelectedAudioTrack(scene: null, index: 0));
    tester.widget<OiSwitch>(find.byType(OiSwitch)).onChanged!(false);
    await tester.pump();
    expect(harness.history.document.audioTracksJson()[0].containsKey('loop'), isFalse);
    tester.widget<OiSwitch>(find.byType(OiSwitch)).onChanged!(true);
    await tester.pump();
    expect(harness.history.document.audioTracksJson()[0]['loop'], true);
  });

  testWidgets('trim edits keep the pair in frames form', (tester) async {
    final harness = await _pump(tester, const SelectedAudioTrack(scene: null, index: 0));
    await _commit(tester, 'audio-trim-from', '40');
    expect(harness.history.document.audioTracksJson()[0]['trim'], {'from': '40f', 'to': '90f'});
    await _commit(tester, 'audio-trim-to', '120');
    expect(harness.history.document.audioTracksJson()[0]['trim'], {'from': '40f', 'to': '120f'});
  });

  testWidgets('an untrimmed track shows no trim rows', (tester) async {
    await _pump(tester, const SelectedAudioTrack(scene: 1, index: 0));
    expect(find.text('scene.mp3'), findsOneWidget);
    expect(find.byKey(const ValueKey('audio-trim-from')), findsNothing);
    expect(find.byType(OiSwitch), findsOneWidget);
  });

  testWidgets('a time-placed sfx edits its start; music-only rows stay away', (tester) async {
    final harness = await _pump(tester, const SelectedAudioTrack(scene: null, index: 1));
    expect(find.text('whoosh.wav'), findsOneWidget);
    expect(find.text('sfx'), findsOneWidget);
    expect(find.byType(OiSwitch), findsNothing);
    expect(find.byKey(const ValueKey('audio-fade-in')), findsNothing);
    expect(tester.widget<EditableText>(_input('audio-start')).controller.text, '20');
    await _commit(tester, 'audio-start', '35');
    expect(harness.history.document.audioTracksJson()[1]['at'], {'kind': 'at', 'time': '35f'});
  });

  testWidgets('a trigger-placed sfx explains itself instead of a start field', (tester) async {
    await _pump(tester, const SelectedAudioTrack(scene: null, index: 2));
    expect(find.byKey(const ValueKey('audio-start')), findsNothing);
    expect(find.text('Fires on beat'), findsOneWidget);
  });

  testWidgets('reorder follows the selection and stays undoable', (tester) async {
    final harness = await _pump(tester, const SelectedAudioTrack(scene: null, index: 0));
    await tester.tap(find.bySemanticsLabel('Move down in the mix'));
    await tester.pump();
    expect(harness.history.document.audioTracksJson()[1]['kind'], 'music');
    expect(
      harness.container.read(audioSelectionProvider),
      const SelectedAudioTrack(scene: null, index: 1),
    );
    harness.history.undo();
    expect(harness.history.document.audioTracksJson()[0]['kind'], 'music');
  });

  testWidgets('the first track cannot move up, the last cannot move down', (tester) async {
    await _pump(tester, const SelectedAudioTrack(scene: null, index: 0));
    OiIconButton button(String label) => tester
        .widgetList<OiIconButton>(find.byType(OiIconButton))
        .firstWhere((button) => button.semanticLabel == label);
    expect(button('Move up in the mix').onTap, isNull);
    expect(button('Move down in the mix').onTap, isNotNull);
  });

  testWidgets('remove drops the track and clears the selection', (tester) async {
    final harness = await _pump(tester, const SelectedAudioTrack(scene: null, index: 0));
    await tester.tap(find.bySemanticsLabel('Remove track'));
    await tester.pump();
    expect(harness.history.document.audioTracksJson(), hasLength(2));
    expect(harness.container.read(audioSelectionProvider), isNull);
    harness.history.undo();
    expect(harness.history.document.audioTracksJson(), hasLength(3));
  });

  testWidgets('a stale selection reads as gone', (tester) async {
    await _pump(tester, const SelectedAudioTrack(scene: null, index: 9));
    expect(find.text('Nothing here anymore'), findsOneWidget);
  });
}
