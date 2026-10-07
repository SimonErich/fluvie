import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'transition_edits_test.dart' show deck;

void main() {
  EditorDocument paired() {
    final doc = deck();
    return transitionDropped(
      doc,
      VideoLaneModel.build(document: doc),
      'lane:v1',
      60,
      const TransitionDragData('crossFade'),
    ).command!.apply(doc);
  }

  test('outer trim and slip retain valid transition; incompatible edge and lane explain why', () {
    final doc = paired();
    final model = VideoLaneModel.build(document: doc);
    final edit = videoBarResized(model, 'el:b', 45, 100);
    expect(edit?.command, isNotNull, reason: edit?.note);
    final trimmed = edit!.command!.apply(doc);
    expect(VideoLaneModel.build(document: trimmed).elementBars['el:b']!.window.end, 100);
    expect(trimmed.spec.scenes.single.transitions, hasLength(1));
    final before = VideoLaneModel.build(document: trimmed);
    final resize = transitionResized(trimmed, before.transitionBars.values.single, 50, 60);
    expect(resize.command, isNotNull, reason: resize.note);
    expect(
      VideoLaneModel.build(
        document: resize.command!.apply(trimmed),
      ).elementBars['el:b']!.window.start,
      50,
    );
    expect(videoSlipped(model, 'el:b', 5, document: doc)?.command, isNotNull);
    final invalid = videoBarResized(model, 'el:b', 40, 105);
    expect(invalid?.command, isNull);
    expect(invalid?.note, contains('transition'));
    final relane = videoBarRelaned(model, 'el:b', 'el-track:b', document: doc);
    expect(relane?.command, isNull);
    expect(relane?.note, contains('same lane'));
  });
  for (final (id, frame, headEnd, tailStart) in [('a', 30, 30, 30), ('b', 75, 75, 75)]) {
    test('razor $id preserves render windows and transfers the correct transition edge', () {
      final doc = paired();
      final history = DocumentHistory(doc);
      final edit = videoBarRazored(
        VideoLaneModel.build(document: doc),
        'el:$id',
        frame,
        document: doc,
        tailId: 'tail',
      );
      expect(edit?.command, isNotNull, reason: edit?.note);
      history.dispatch(edit!.command!);
      final next = history.document;
      final model = VideoLaneModel.build(document: next);
      expect(model.elementBars['el:$id']!.window.end, headEnd);
      expect(model.elementBars['el:tail']!.window.start, tailStart);
      final edge = next.spec.scenes.single.transitions.single;
      expect(edge.outgoing, id == 'a' ? 'tail' : 'a');
      expect(edge.incoming, 'b');
      expect(
        videoBarRazored(VideoLaneModel.build(document: doc), 'el:$id', 55, document: doc)?.command,
        isNull,
      );
      history.undo();
      expect(history.document.toJson(), doc.toJson());
      history.dispose();
    });
  }
  test('razor keeps nested clips in their group coordinate frame', () {
    final doc = EditorDocument.fromJson(const {
      'fluvieSpec': 1,
      'fps': 30,
      'scenes': [
        {
          'duration': '180f',
          'children': [
            {
              'id': 'group',
              'type': 'Group',
              'show': {'from': '20f', 'to': '120f'},
              'children': [
                {
                  'id': 'clip',
                  'type': 'Clip',
                  'source': {'kind': 'asset', 'value': 'clip.mp4'},
                  'show': {'from': '10f', 'to': '90f'},
                  'trim': {'from': '1s', 'to': '4s'},
                },
              ],
            },
          ],
        },
      ],
    });
    final edit = videoBarRazored(
      VideoLaneModel.build(document: doc),
      'el:clip',
      60,
      document: doc,
      tailId: 'tail',
    );
    expect(edit?.command, isNotNull, reason: edit?.note);
    final next = edit!.command!.apply(doc);
    expect(next.parentGroupOf('tail'), 'group');
    expect(next.elementJson('tail')!['show'], {'from': '40f', 'to': '90f'});
    expect(VideoLaneModel.build(document: next).elementBars['el:tail']!.window.start, 60);
  });
}
