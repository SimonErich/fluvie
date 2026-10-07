import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show Ease, KeyframedNumber, Time;
import 'package:fluvie/rendering.dart' show integrateClipSpeedRamp;
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiThemeData;

EditorDocument _deck() => EditorDocument.fromJson({
  'fluvieSpec': 1,
  'fps': 30,
  'lanes': const [
    {'id': 'v1'},
    {'id': 'v2'},
  ],
  'scenes': [
    for (var i = 0; i < 3; i++)
      {
        'duration': '120f',
        'children': [
          {
            'id': 'clip$i',
            'type': 'Clip',
            'shared': 'hero',
            'lane': i == 1 ? 'v2' : 'v1',
            'source': {'kind': 'asset', 'value': 'source$i.mp4'},
            'show': {'from': '10f', 'to': '70f'},
            'speed': [1, 2, -0.5][i],
            'trim': {'from': '${i + 1}s', 'to': '${i + 5}s'},
            'audio': {'volume': 0.7},
            'transform': {'x': i * 0.1, 'y': i * 0.05},
          },
        ],
      },
  ],
});

VideoLaneEdit? _slip(EditorDocument document, int frames) => videoSlipped(
  VideoLaneModel.build(document: document),
  'el:clip0',
  frames,
  document: document,
);

void main() {
  test('shared slip shifts each source clock and preserves all other authored content', () {
    final original = _deck();
    final edit = _slip(original, 15)!;
    expect(edit.command, isNotNull, reason: edit.note);
    final history = DocumentHistory(original)..dispatch(edit.command!);
    addTearDown(history.dispose);
    for (var i = 0; i < 3; i++) {
      final from = i + 1 + [0.5, 1.0, 0.25][i];
      expect(history.document.elementJson('clip$i'), {
        ...original.elementJson('clip$i')!,
        'trim': {'from': '${from}s', 'to': '${from + 4}s'},
      });
    }
    history.undo();
    expect(history.document.toJson(), original.toJson());
    expect(history.canUndo, isFalse);
    history.redo();
    expect(history.document.sharedChainIds('clip1'), ['clip0', 'clip1', 'clip2']);
  });

  test('a locked peer and an unreadable source refuse the entire shared slip', () {
    final original = _deck();
    final locked = const SetLaneCommand(id: 'v2', patch: {'locked': true}).apply(original);
    expect(_slip(locked, 15)!.command, isNull);
    expect(_slip(locked, 15)!.note, contains('Unlock'));
    final unreadable = original.replaceElement('clip1', {
      ...original.elementJson('clip1')!,
      'trim': {'from': '10f', 'to': '30f'},
    });
    expect(_slip(unreadable, 15)!.command, isNull);
    expect(_slip(unreadable, 15)!.note, contains('seconds'));
    final mixed = original.replaceElement('clip1', {
      'id': 'clip1',
      'type': 'Text',
      'text': 'A title',
      'shared': 'hero',
    });
    expect(_slip(mixed, 15)!.note, contains('Only a clip'));
    expect(original.elementJson('clip0')!['trim'], {'from': '1s', 'to': '5s'});
  });

  test('shared slip clamps the whole gesture at its first source boundary', () {
    final original = _deck();
    final edit = _slip(original, -60)!;
    expect(edit.command, isNotNull, reason: edit.note);
    expect(edit.note, contains('source start'));
    final changed = edit.command!.apply(original);
    expect(changed.elementJson('clip0')!['trim'], {'from': '0.0s', 'to': '4.0s'});
    expect(changed.elementJson('clip1')!['trim'], {'from': '0.0s', 'to': '4.0s'});
    expect(changed.elementJson('clip2')!['trim'], {'from': '2.5s', 'to': '6.5s'});
    expect(_slip(changed, -1)!.command, isNull);
  });

  test('slipping a ramp follows its integrated source clock and materializes an open end', () {
    final original = _deck();
    const ramp = KeyframedNumber(
      values: [1, 3],
      positions: [Time.relative(0), Time.relative(1)],
      easings: [Ease.smooth],
    );
    final ramped = original.splitSharedMembers({
      for (var i = 0; i < 3; i++)
        'clip$i': {...original.elementJson('clip$i')!, 'speed': ramp.toJson()}..remove('trim'),
    }, const {});
    final edit = _slip(ramped, 15)!;
    expect(edit.command, isNotNull, reason: edit.note);
    final changed = edit.command!.apply(ramped);
    final map = integrateClipSpeedRamp(ramp, fps: 30, windowFrames: 60);
    for (var i = 0; i < 3; i++) {
      expect(changed.elementJson('clip$i')!['trim'], {
        'from': '${map[15]}s',
        'to': '${map[15] + map.last}s',
      });
      expect(changed.elementJson('clip$i')!['speed'], ramp.toJson());
    }
    final extended = _slip(ramped, 75)!.command!.apply(ramped);
    final end = map.last + 15 * (map.last - map[59]);
    expect(extended.elementJson('clip0')!['trim'], {
      'from': '${end}s',
      'to': '${end + map.last}s',
    });
    final back = _slip(changed, -1)!.command!.apply(changed);
    expect(back.elementJson('clip0')!['trim'], {
      'from': '${map[15] - map[1]}s',
      'to': '${map[15] + map.last - map[1]}s',
    });
  });

  testWidgets('Alt drag retains every member baseline and returns exactly to its starting source', (
    tester,
  ) async {
    final original = _deck();
    final history = DocumentHistory(original);
    final transport = SlideTransport(fps: 30, length: 360);
    final container = ProviderContainer();
    addTearDown(history.dispose);
    addTearDown(transport.dispose);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: OiApp(
          title: 'Shared slip',
          theme: OiThemeData.dark(),
          home: ListenableBuilder(
            listenable: history,
            builder: (context, _) => SizedBox(
              width: 800,
              height: 350,
              child: VideoModePanel(
                document: history.document,
                transport: transport,
                onCommand: history.dispatch,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    TrackTimeline timeline() => tester.widget<TrackTimeline>(find.byType(TrackTimeline));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    timeline().edit.onDragStarted!('el:clip0');
    for (final start in [25.0, 40.0, 10.0, 25.0]) {
      timeline().edit.onBarMoved!('el:clip0', start, 'lane:v1');
      await tester.pump();
      if (start == 10) {
        expect(history.document.toJson(), original.toJson());
      } else {
        final from = 2 + (start - 10) / 30 * 2;
        expect(history.document.elementJson('clip1')!['trim'], {
          'from': '${from}s',
          'to': '${from + 4}s',
        });
      }
    }
    timeline().edit.onDragEnded!('el:clip0');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    history.undo();
    expect(history.document.toJson(), original.toJson());
    expect(history.canUndo, isFalse);
    expect(tester.takeException(), isNull);
  });
}
