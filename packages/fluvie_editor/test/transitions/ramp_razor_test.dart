import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:fluvie_editor/src/video_mode/clip_trim_seconds.dart';
import 'transition_edits_test.dart' show deck;

void main() {
  for (final ease in [Curves.linear, Ease.smooth, Ease.bounce, Ease.elastic]) {
    test('razor preserves every source sample and eased rate for $ease', () {
      final base = deck();
      final ramp = KeyframedNumber(
        values: const [1, 3, 2],
        positions: const [Time.relative(0), Time.relative(.6), Time.relative(1)],
        easings: [ease, ease],
      );
      final doc = clipSpeedRampEdited(base, 'a', ramp, durationFrames: 60).command!.apply(base);
      final original = KeyframedNumber.maybeFromJson(doc.elementJson('a')!['speed'])!;
      final whole = integrateClipSpeedRamp(original, fps: 30, windowFrames: 60);
      for (final cut in [1, 17, 36, 59]) {
        final edit = videoBarRazored(
          VideoLaneModel.build(document: doc),
          'el:a',
          cut,
          document: doc,
          tailId: 'tail',
        );
        expect(edit?.command, isNotNull, reason: edit?.note);
        final history = DocumentHistory(doc)..dispatch(edit!.command!);
        final result = history.document;
        for (final entry in [('a', 0, cut), ('tail', cut, 60 - cut)]) {
          final json = result.elementJson(entry.$1)!;
          final sliced = KeyframedNumber.maybeFromJson(json['speed'])!;
          final map = integrateClipSpeedRamp(sliced, fps: 30, windowFrames: entry.$3);
          final trim = readClipTrimSeconds(json)!;
          for (var frame = 0; frame <= entry.$3; frame++) {
            expect(
              trim.from + map[frame],
              closeTo(1 + whole[entry.$2 + frame], 1e-8),
              reason: '${entry.$1} frame $frame cut $cut',
            );
          }
          expect(sliced.toJson()['easings'], original.toJson()['easings']);
          for (final srcFps in [24.0, 30000 / 1001, 60.0]) {
            final meta = (fps: srcFps, frameCount: 1000, width: 10, height: 10, hasAudio: true);
            int sample(double from, double to, List<double> mapping, int frame) {
              final time = Time.seconds(from).to(Time.seconds(to));
              final bounds = resolveClipTrimBounds(time, meta);
              final offsets = resolveClipTrimOffsets(time, meta);
              return resampleClipFrame(
                compFrame: frame,
                windowStart: 0,
                compFps: 30,
                srcFps: srcFps,
                trimStartFrames: bounds.start,
                trimEndFrames: bounds.end,
                trimStartOffsetFrames: offsets.start - bounds.start,
                trimEndOffsetFrames: offsets.end - bounds.end,
                sourceTimeMap: mapping,
              );
            }

            for (var frame = 0; frame < entry.$3; frame++) {
              expect(
                sample(trim.from, trim.to, map, frame),
                sample(1, 3, whole, entry.$2 + frame),
                reason: 'exact source frame at fps $srcFps cut $cut frame $frame',
              );
            }
          }
        }
        history.undo();
        expect(history.document.toJson(), doc.toJson());
        history.dispose();
      }
    });
  }
}
