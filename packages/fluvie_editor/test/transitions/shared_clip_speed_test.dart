import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show Ease, KeyframedNumber, Time;
import 'package:fluvie/rendering.dart' show integrateClipSpeedRamp;
import 'package:fluvie_editor/fluvie_editor.dart';

EditorDocument sharedDeck() => EditorDocument.fromJson({
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
            'source': {'kind': 'asset', 'value': 'source.mp4'},
            'show': {'from': '10f', 'to': '70f'},
            'trim': {'from': '${i * 2 + 0.123}s', 'to': '${i * 2 + 2.123}s'},
            'transform': {'x': i * 0.1, 'y': i * 0.05},
          },
        ],
      },
  ],
});

void expectLocalState(EditorDocument before, EditorDocument after) {
  for (var i = 0; i < 3; i++) {
    final original = before.elementJson('clip$i')!;
    final changed = after.elementJson('clip$i')!;
    for (final key in ['id', 'shared', 'lane', 'source', 'trim', 'transform']) {
      expect(changed[key], original[key], reason: '$key stays local on clip$i');
    }
  }
  expect(after.sharedChainIds('clip0'), ['clip0', 'clip1', 'clip2']);
}

void main() {
  test('shared scalar speed preserves each source phase and geometry in one undo step', () {
    final original = sharedDeck();
    final edit = clipSpeedEdited(original, 'clip1', 2);
    expect(edit.command, isNotNull, reason: edit.note);
    final history = DocumentHistory(original)..dispatch(edit.command!);
    expectLocalState(original, history.document);
    for (var i = 0; i < 3; i++) {
      expect(history.document.elementJson('clip$i')!['speed'], closeTo(2, 1e-12));
      expect(history.document.elementJson('clip$i')!['show'], {'from': '10f', 'to': '40f'});
    }
    history.undo();
    expect(history.document.toJson(), original.toJson());
    expect(history.canUndo, isFalse);
    history.redo();
    expectLocalState(original, history.document);
    history.dispose();
  });

  test('shared rate stretch reaches the logical right edge and coalesces a drag', () {
    final original = sharedDeck();
    final history = DocumentHistory(original);
    for (final end in [295, 280]) {
      final edit = clipRateStretched(
        history.document,
        VideoLaneModel.build(document: history.document),
        'el:clip0',
        end.toDouble(),
        mergeGroup: 'shared-drag',
      );
      expect(edit.command, isNotNull, reason: edit.note);
      history.dispatch(edit.command!);
      expect(
        VideoLaneModel.build(document: history.document).elementBars['el:clip0']!.window.end,
        end,
      );
    }
    expectLocalState(original, history.document);
    for (var i = 0; i < 3; i++) {
      expect(history.document.elementJson('clip$i')!['speed'], closeTo(2, 1e-12));
    }
    history.undo();
    expect(history.document.toJson(), original.toJson());
    expect(history.canUndo, isFalse);
    history.dispose();
  });

  test('shared eased ramp and rate stretch consume each original trim exactly', () {
    final original = sharedDeck();
    const ramp = KeyframedNumber(
      values: [1, 3, 1],
      positions: [Time.relative(0), Time.relative(0.5), Time.relative(1)],
      easings: [Ease.smooth, Ease.inOut],
    );
    final edit = clipSpeedRampEdited(original, 'clip2', ramp);
    expect(edit.command, isNotNull, reason: edit.note);
    var changed = edit.command!.apply(original);
    final stretch = clipRateStretched(
      changed,
      VideoLaneModel.build(document: changed),
      'el:clip0',
      295,
    );
    expect(stretch.command, isNotNull, reason: stretch.note);
    changed = stretch.command!.apply(changed);
    expectLocalState(original, changed);
    expect(VideoLaneModel.build(document: changed).elementBars['el:clip0']!.window.end, 295);
    for (var i = 0; i < 3; i++) {
      final current = KeyframedNumber.maybeFromJson(changed.elementJson('clip$i')!['speed'])!;
      expect(current.easings, ramp.easings);
      expect(integrateClipSpeedRamp(current, fps: 30, windowFrames: 45).last, closeTo(2, 1e-10));
    }
  });

  test('a locked peer or owner overflow refuses the entire shared speed edit', () {
    final original = sharedDeck();
    final locked = const SetLaneCommand(id: 'v2', patch: {'locked': true}).apply(original);
    final refusal = clipSpeedEdited(locked, 'clip0', 2);
    expect(refusal.command, isNull);
    expect(refusal.note, contains('Unlock'));
    final overflow = clipSpeedEdited(original, 'clip0', 0.25);
    expect(overflow.command, isNull);
    expect(overflow.note, contains('fit'));
    expect(original.elementJson('clip0')!['speed'], isNull);
  });

  test('shared reverse retains each source range and an open trim is materialized locally', () {
    final original = sharedDeck();
    final reversed = clipSpeedEdited(original, 'clip0', -2).command!.apply(original);
    expectLocalState(original, reversed);
    for (var i = 0; i < 3; i++) {
      expect(reversed.elementJson('clip$i')!['speed'], closeTo(-2, 1e-12));
    }
    final open = original.splitSharedMembers({
      for (var i = 0; i < 3; i++) 'clip$i': {...original.elementJson('clip$i')!}..remove('trim'),
    }, const {});
    final changed = clipSpeedEdited(open, 'clip1', 2).command!.apply(open);
    for (var i = 0; i < 3; i++) {
      expect(changed.elementJson('clip$i')!['trim'], {'from': '0.0s', 'to': '2.0s'});
      expect(changed.elementJson('clip$i')!['show'], {'from': '10f', 'to': '40f'});
    }
  });

  test('a heterogeneous shared chain and a stretch past the final start explain refusal', () {
    final original = sharedDeck();
    final mixed = original.replaceElement('clip1', {
      'id': 'clip1',
      'type': 'Text',
      'text': 'A title',
      'shared': 'hero',
    });
    final refusal = clipSpeedEdited(mixed, 'clip0', 2);
    expect(refusal.command, isNull);
    expect(refusal.note, contains('Shared clip clip1'));
    final short = clipRateStretched(
      original,
      VideoLaneModel.build(document: original),
      'el:clip0',
      250,
    );
    expect(short.command, isNull);
    expect(short.note, contains('last shared member'));
  });
}
