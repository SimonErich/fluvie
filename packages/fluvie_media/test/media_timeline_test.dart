import 'package:fluvie_media/fluvie_media.dart';
import 'package:test/test.dart';

void main() {
  test('serialized timelines preserve exact source intervals across bridges', () {
    final irregular = MediaTimeline.fromTimestamps([5000000, 5100000, 5400000], endTimeUs: 5500000);
    final restored = MediaTimeline.fromJson(irregular.toJson());
    expect(restored.frameAt(0.35), 1);
    expect(restored.timeForFrame(2), 0.4);
    expect(restored.durationSeconds, 0.5);
    final constant = MediaTimeline.fromJson(
      MediaTimeline.constant(fps: 30, frameCount: 6).toJson(),
    );
    expect(constant.frameCount, 6);
    expect(constant.durationSeconds, 0.2);
    expect(() => MediaTimeline.fromJson({'schemaVersion': 2}), throwsFormatException);
  });

  test('constant timing selects held frames and clamps source boundaries', () {
    final timeline = MediaTimeline.constant(fps: 10, frameCount: 4);
    expect(timeline.frameAt(-1), 0);
    expect(timeline.frameAt(0.099), 0);
    expect(timeline.frameAt(0.1), 1);
    expect(timeline.frameAt(2), 3);
    expect(timeline.timeForFrame(2), 0.2);
    expect(timeline.durationSeconds, 0.4);
  });

  test('variable timing uses display intervals instead of average fps', () {
    final timeline = MediaTimeline.fromTimestamps(
      [5000000, 5100000, 5400000, 5900000],
      endTimeUs: 6000000,
    );
    expect(timeline.frameAt(-1), 0);
    expect(timeline.frameAt(0.099), 0);
    expect(timeline.frameAt(0.1), 1);
    expect(timeline.frameAt(0.35), 1);
    expect(timeline.frameAt(0.4), 2);
    expect(timeline.frameAt(0.89), 2);
    expect(timeline.frameAt(0.9), 3);
    expect(timeline.timeForFrame(3), 0.9);
    expect(timeline.durationSeconds, 1);
  });

  test('interpolation follows irregular neighboring presentation times', () {
    final timeline = MediaTimeline.fromTimestamps([0, 100000, 400000], endTimeUs: 500000);
    final blend = timeline.interpolationAt(0.25);
    expect((blend.index, blend.nextIndex), (1, 2));
    expect(blend.fraction, closeTo(0.5, 1e-12));
    expect(timeline.interpolationAt(0.45), (index: 2, nextIndex: 2, fraction: 0.0));
  });

  test('duplicate timestamps hold the final picture at that timestamp', () {
    final timeline = MediaTimeline.fromTimestamps([0, 100000, 100000, 400000], endTimeUs: 500000);
    expect(timeline.frameAt(0.1), 2);
    expect(timeline.frameAt(0.25), 2);
  });

  test('one frame has its complete explicitly supplied interval', () {
    final timeline = MediaTimeline.fromTimestamps([7000000], endTimeUs: 7500000);
    expect(timeline.frameAt(0.4), 0);
    expect(timeline.durationSeconds, 0.5);
  });

  test('timestamps are immutable and malformed source clocks fail', () {
    final source = [0, 100000, 400000];
    final timeline = MediaTimeline.fromTimestamps(source, endTimeUs: 500000);
    source[1] = 300000;
    expect(timeline.frameAt(0.2), 1);
    expect(() => MediaTimeline.fromTimestamps([]), throwsArgumentError);
    expect(() => MediaTimeline.fromTimestamps([10, 5]), throwsArgumentError);
    expect(() => MediaTimeline.fromTimestamps([10, 20], endTimeUs: 20), throwsArgumentError);
    expect(() => MediaTimeline.constant(fps: 0, frameCount: 4), throwsArgumentError);
    expect(() => MediaTimeline.constant(fps: 10, frameCount: 0), throwsArgumentError);
    expect(() => timeline.frameAt(double.nan), throwsArgumentError);
  });
}
