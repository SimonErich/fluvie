import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:fluvie_editor/src/video_mode/video_lift.dart';
import 'video_continuity_acceptance_test.dart' show deck;

void main() {
  test('razor splits a shared chain into independent chains while preserving each geometry', () {
    final document = EditorDocument.fromJson(deck());
    final history = DocumentHistory(document);
    final edit = videoBarRazored(
      VideoLaneModel.build(document: document),
      'el:title0',
      90,
      document: document,
      tailId: 'tail',
    );
    expect(edit?.command, isNotNull);
    history.dispatch(edit!.command!);
    final result = history.document;
    expect(result.sharedChainIds('title0'), ['title0', 'title1']);
    expect(result.sharedChainIds('tail'), ['tail', 'title2']);
    expect(result.elementJson('title1')!['show'], {'from': '0f', 'to': '30f'});
    expect(result.elementJson('tail')!['show'], {'from': '30f', 'to': '60f'});
    expect(result.elementJson('tail')!['transform'], document.elementJson('title1')!['transform']);
    expect(
      result.elementJson('title2')!['transform'],
      document.elementJson('title2')!['transform'],
    );
    final model = VideoLaneModel.build(document: result);
    expect(model.elementBars.values.map((bar) => (bar.window.start, bar.window.end)).toSet(), {
      (0, 90),
      (90, 180),
    });
    history.undo();
    expect(history.document.toJson(), document.toJson());
    history.dispose();
  });
  test('ripple delete removes all shared memberships and closes per-scene gaps', () {
    final raw = deck()..remove('overlays');
    for (final scene in (raw['scenes']! as List).cast<Map<String, Object?>>()) {
      final children = scene['children']! as List;
      (children.first as Map)['show'] = {'from': '0f', 'to': '30f'};
      children.add({
        'type': 'Text',
        'id': 'after${(children.first as Map)['id']}',
        'text': 'Next',
        'show': {'from': '30f', 'to': '60f'},
      });
    }
    final doc = EditorDocument.fromJson(raw);
    final edit = videoRippleDeleted(VideoLaneModel.build(document: doc), {
      'el:title0',
    }, document: doc);
    expect(edit?.command, isNotNull);
    final result = edit!.command!.apply(doc);
    for (var scene = 0; scene < 3; scene++) {
      expect(result.elementJson('title$scene'), isNull);
      expect(result.elementJson('aftertitle$scene')!['show'], {'from': '0f', 'to': '30f'});
    }
  });
  test('marked range lifts across shared memberships, including an exact scene cut', () {
    for (final start in [50, 60]) {
      final original = EditorDocument.fromJson(deck());
      final edit = videoRangeRemoved(
        VideoLaneModel.build(document: original),
        start,
        130,
        document: original,
        bars: {'el:title0'},
      );
      expect(edit?.command, isNotNull, reason: edit?.note);
      final result = edit!.command!.apply(original);
      final bars = VideoLaneModel.build(document: result).elementBars.values;
      expect(bars.map((bar) => (bar.window.start, bar.window.end)).toSet(), {
        (0, start),
        (130, 180),
      });
    }
  });
}
