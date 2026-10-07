import 'package:flutter/painting.dart' show Alignment;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

/// The editor reads and writes the spec's own JSON forms; these codecs are
/// reachable from the barrel so no consumer ever imports `src/`.
void main() {
  test('decodeTime is reachable and reads the frames form', () {
    final time = decodeTime('12f');
    expect(time, isA<FrameTime>());
    expect((time as FrameTime).frames, 12);
  });

  test('namedEases carries the curated easing vocabulary', () {
    expect(namedEases.keys, contains('bounce'));
    expect(identical(namedEases['smooth'], Ease.smooth), isTrue);
  });

  test('namedAlignments carries the nine standard alignments', () {
    expect(namedAlignments, hasLength(9));
    expect(namedAlignments['center'], Alignment.center);
  });

  test('keyframes round-trip through decodeKeyframe and encodeKeyframe', () {
    final keyframe = decodeKeyframe(const {'x': 0.5, 'opacity': 0.25});
    expect(keyframe.x, 0.5);
    expect(encodeKeyframe(keyframe), {'x': 0.5, 'opacity': 0.25});
  });
}
