import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show KeyframedNumber, Time;
import 'package:fluvie/rendering.dart' show integrateClipSpeedRamp;
import 'package:fluvie_editor/fluvie_editor.dart';

EditorDocument deck() => EditorDocument.fromJson({
  'fluvieSpec': 1,
  'fps': 30,
  'lanes': const [
    {'id': 'v1'},
  ],
  'scenes': [
    {
      'duration': '180f',
      'children': [
        for (var i = 0; i < 2; i++)
          {
            'id': i == 0 ? 'a' : 'b',
            'type': 'Clip',
            'lane': 'v1',
            'source': {'kind': 'asset', 'value': '$i.mp4'},
            'show': {'from': '${i * 60}f', 'to': '${(i + 1) * 60}f'},
            'trim': {'from': '1s', 'to': '3s'},
          },
      ],
    },
  ],
});

void main() {
  test('absolute ramp stops solve duration and an open ramp materializes its consumed source', () {
    final original = deck();
    final ramp = KeyframedNumber.linear(
      values: const [1, 2],
      positions: const [Time.zero, Time.frames(60)],
    );
    final edit = clipSpeedRampEdited(original, 'a', ramp);
    expect(edit.command, isNotNull, reason: edit.note);
    final result = edit.command!.apply(original);
    final duration = VideoLaneModel.build(
      document: result,
    ).elementBars['el:a']!.window.durationFrames;
    expect(duration, lessThan(60));
    expect(
      integrateClipSpeedRamp(
        KeyframedNumber.maybeFromJson(result.elementJson('a')!['speed'])!,
        fps: 30,
        windowFrames: duration,
      ).last,
      closeTo(2, 1e-10),
    );
    final open = original.replaceElement(
      'a',
      {
          ...original.elementJson('a')!,
          'speed': {
            'values': [1, 3],
            'positions': ['0r', '1r'],
          },
        }
        ..remove('show')
        ..remove('trim'),
    );
    final changed = clipSpeedEdited(open, 'a', 4).command!.apply(open);
    expect(changed.elementJson('a')!['show'], {'from': '0f', 'to': '90f'});
    expect(changed.elementJson('a')!['trim'], {'from': '0.0s', 'to': '12.0s'});
    final sameRamp = clipSpeedRampEdited(
      open,
      'a',
      KeyframedNumber.linear(
        values: const [2, 2],
        positions: const [Time.relative(0), Time.relative(1)],
      ),
    );
    expect(sameRamp.command, isNotNull, reason: sameRamp.note);
  });
  test('ramp and scalar speed validate linked transitions and impossible source clocks', () {
    final original = deck();
    final linked = transitionDropped(
      original,
      VideoLaneModel.build(document: original),
      'lane:v1',
      60,
      const TransitionDragData('crossFade'),
    ).command!.apply(original);
    expect(clipSpeedEdited(linked, 'a', 4).note, contains('Speed refused'));
    expect(
      clipSpeedRampEdited(
        original,
        'a',
        KeyframedNumber.linear(
          values: const [0.01, 0.01],
          positions: const [Time.zero, Time.frames(60)],
        ),
      ).note,
      contains('longer scene'),
    );
    final invalid = KeyframedNumber.linear(
      values: const [1, -1],
      positions: const [Time.zero, Time.frames(60)],
    );
    expect(clipSpeedRampEdited(original, 'a', invalid).note, contains('Speed ramp refused'));
  });
  test('replacing and removing a transition restores the authored clip cut with undo', () {
    final original = deck();
    final first = transitionDropped(
      original,
      VideoLaneModel.build(document: original),
      'lane:v1',
      60,
      const TransitionDragData('wipe'),
    );
    var current = first.command!.apply(original);
    final second = transitionDropped(
      current,
      VideoLaneModel.build(document: current),
      'lane:v1',
      60,
      const TransitionDragData('slide'),
    );
    expect(second.command, isNotNull, reason: second.note);
    current = second.command!.apply(current);
    expect(current.spec.scenes.single.transitions, hasLength(1));
    final history = DocumentHistory(current);
    final model = VideoLaneModel.build(document: current);
    history.dispatch(transitionRemoved(current, model.transitionBars.values.single).command!);
    expect(history.document.spec.scenes.single.transitions, isEmpty);
    expect(VideoLaneModel.build(document: history.document).elementBars['el:b']!.window.start, 60);
    history.undo();
    expect(history.document.toJson(), current.toJson());
    final locked = const SetLaneCommand(id: 'v1', patch: {'locked': true}).apply(current);
    expect(
      transitionRemoved(
        locked,
        VideoLaneModel.build(document: locked).transitionBars.values.single,
      ).command,
      isNull,
    );
    final invalidMove = videoBarMoved(model, 'el:a', 10)!;
    expect(invalidMove.command, isNull);
    expect(invalidMove.note, contains('transition'));
    history.dispose();
  });
  test('drop snaps to a cut and duration edits change picture and audio together', () {
    var doc = deck();
    var model = VideoLaneModel.build(document: doc);
    final dropped = transitionDropped(
      doc,
      model,
      'lane:v1',
      61,
      const TransitionDragData('crossFade'),
    );
    expect(dropped.command, isNotNull);
    doc = dropped.command!.apply(doc);
    model = VideoLaneModel.build(document: doc);
    expect(model.elementBars['el:b']!.window.start, 45);
    final binding = model.transitionBars.values.single;
    expect((binding.window.start, binding.window.end), (45, 60));
    final edit = transitionResized(doc, binding, 50, 60, mergeGroup: 'drag');
    doc = edit.command!.apply(doc);
    expect(VideoLaneModel.build(document: doc).elementBars['el:b']!.window.start, 50);
    expect(
      doc.spec.scenes.single.transitions.single.transition.duration.toString(),
      contains('10'),
    );
  });
  test('oversized duration refuses with a useful note and no mutation', () {
    final doc = deck();
    final model = VideoLaneModel.build(document: doc);
    final edit = transitionDropped(
      doc,
      model,
      'lane:v1',
      60,
      const TransitionDragData('crossFade', durationFrames: 70),
    );
    expect(edit.command, isNull);
    expect(edit.note, isNotEmpty);
    expect(doc.spec.scenes.single.transitions, isEmpty);
  });
  test('locked lane refuses a transition drop', () {
    final doc = const SetLaneCommand(id: 'v1', patch: {'locked': true}).apply(deck());
    final edit = transitionDropped(
      doc,
      VideoLaneModel.build(document: doc),
      'lane:v1',
      60,
      const TransitionDragData('wipe'),
    );
    expect(edit.command, isNull);
    expect(edit.note, contains('Unlock'));
  });
  test('speed number, reverse and rate-stretch preserve the selected source range', () {
    var doc = deck();
    doc = clipSpeedEdited(doc, 'a', 2).command!.apply(doc);
    expect(doc.elementJson('a')!['show'], {'from': '0f', 'to': '30f'});
    expect(doc.elementJson('a')!['trim'], {'from': '1.0s', 'to': '3.0s'});
    doc = clipSpeedEdited(doc, 'a', -2).command!.apply(doc);
    expect(doc.elementJson('a')!['speed'], -2);
    final model = VideoLaneModel.build(document: doc);
    doc = clipRateStretched(doc, model, 'el:a', 45).command!.apply(doc);
    expect(doc.elementJson('a')!['speed'], closeTo(-4 / 3, 1e-10));
    expect(doc.elementJson('a')!['show'], {'from': '0f', 'to': '45f'});
  });
  test('transition duration drag coalesces as one undo', () {
    final original = deck();
    final history = DocumentHistory(original)
      ..dispatch(
        transitionDropped(
          original,
          VideoLaneModel.build(document: original),
          'lane:v1',
          60,
          const TransitionDragData('crossFade'),
        ).command!,
      );
    final baseline = history.document.toJson();
    for (final duration in [12, 10, 8]) {
      final binding = VideoLaneModel.build(document: history.document).transitionBars.values.single;
      history.dispatch(
        transitionResized(
          history.document,
          binding,
          (60 - duration).toDouble(),
          60,
          mergeGroup: 'drag',
        ).command!,
      );
    }
    history.undo();
    expect(history.document.toJson(), baseline);
    history.dispose();
  });
  test('positive speed ramp and rate stretch preserve source in/out through the integral', () {
    var doc = deck();
    final ramp = KeyframedNumber.linear(
      values: const [1, 3],
      positions: const [Time.relative(0), Time.relative(1)],
    );
    doc = clipSpeedRampEdited(doc, 'a', ramp).command!.apply(doc);
    expect(doc.elementJson('a')!['show'], {'from': '0f', 'to': '30f'});
    final fitted = KeyframedNumber.maybeFromJson(doc.elementJson('a')!['speed'])!;
    expect(integrateClipSpeedRamp(fitted, fps: 30, windowFrames: 30).last, closeTo(2, 1e-10));
    doc = clipRateStretched(
      doc,
      VideoLaneModel.build(document: doc),
      'el:a',
      60,
    ).command!.apply(doc);
    expect(doc.elementJson('a')!['show'], {'from': '0f', 'to': '60f'});
    final stretched = KeyframedNumber.maybeFromJson(doc.elementJson('a')!['speed'])!;
    expect(stretched.values, [0.5, 1.5]);
    expect(integrateClipSpeedRamp(stretched, fps: 30, windowFrames: 60).last, closeTo(2, 1e-10));
  });
}
