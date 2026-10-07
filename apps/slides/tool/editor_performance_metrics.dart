import 'dart:ui' show FramePhase;

import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

/// Engine timings for the active interaction, separate from test-driver latency.
///
/// The engine batches timings up to once per second. Flush before subscribing
/// and after the interaction, as Flutter's integration performance watcher does.
final class EditorFrameMetrics {
  EditorFrameMetrics._();

  final List<FrameTiming> _frames = [];
  bool _listening = true;

  static Future<EditorFrameMetrics> start(WidgetTester tester) async {
    await _flush(tester);
    final metrics = EditorFrameMetrics._();
    SchedulerBinding.instance.addTimingsCallback(metrics._record);
    addTearDown(metrics._unsubscribe);
    return metrics;
  }

  void _record(List<FrameTiming> frames) => _frames.addAll(frames);

  Future<Map<String, Object>> finish(WidgetTester tester) async {
    await _stop(tester);
    return _summary(_frames);
  }

  /// Separates adjacent interactions without a timing-flush pause between them.
  /// [lastBeforeFrame] is the engine frame number after the first interaction's
  /// final pump. Batched timing delivery cannot move a frame across this split.
  Future<({Map<String, Object> before, Map<String, Object> after})> finishSplit(
    WidgetTester tester, {
    required int lastBeforeFrame,
  }) async {
    await _stop(tester);
    return (
      before: _summary(_frames.where((frame) => frame.frameNumber <= lastBeforeFrame)),
      after: _summary(_frames.where((frame) => frame.frameNumber > lastBeforeFrame)),
    );
  }

  Future<void> _stop(WidgetTester tester) async {
    try {
      await _flush(tester);
    } finally {
      _unsubscribe();
    }
  }

  void _unsubscribe() {
    if (!_listening) {
      return;
    }
    _listening = false;
    SchedulerBinding.instance.removeTimingsCallback(_record);
  }

  static Duration _rasterWait(FrameTiming frame) => Duration(
    microseconds:
        frame.timestampInMicroseconds(FramePhase.rasterStart) -
        frame.timestampInMicroseconds(FramePhase.buildFinish),
  );

  static Map<String, Object> _summary(Iterable<FrameTiming> source) {
    final frames = source.toList()..sort((a, b) => a.frameNumber.compareTo(b.frameNumber));
    expect(frames, isNotEmpty, reason: 'The engine must report actual interaction frames');
    return {
      'count': frames.length,
      'build': _timings(frames.map((frame) => frame.buildDuration)),
      'raster': _timings(frames.map((frame) => frame.rasterDuration)),
      'vsyncOverhead': _timings(frames.map((frame) => frame.vsyncOverhead)),
      'buildToRasterWait': _timings(frames.map(_rasterWait)),
      'totalSpan': _timings(frames.map((frame) => frame.totalSpan)),
      // Keep paired values and monotonic timestamps: independent sorted
      // aggregates alone cannot identify which phase caused a particular spike.
      'orderedFrames': [
        for (final frame in frames)
          {
            'frameNumber': frame.frameNumber,
            'buildMs': frame.buildDuration.inMicroseconds / 1000,
            'rasterMs': frame.rasterDuration.inMicroseconds / 1000,
            'vsyncOverheadMs': frame.vsyncOverhead.inMicroseconds / 1000,
            'buildToRasterWaitMs': _rasterWait(frame).inMicroseconds / 1000,
            'totalSpanMs': frame.totalSpan.inMicroseconds / 1000,
            'timestampsUs': {
              for (final phase in const [
                FramePhase.vsyncStart,
                FramePhase.buildStart,
                FramePhase.buildFinish,
                FramePhase.rasterStart,
                FramePhase.rasterFinish,
              ])
                phase.name: frame.timestampInMicroseconds(phase),
            },
          },
      ],
    };
  }

  static Map<String, Object> _timings(Iterable<Duration> durations) {
    final values = durations.map((value) => value.inMicroseconds / 1000).toList()..sort();
    return {
      'medianMs': values[values.length ~/ 2],
      'p95Ms': values[((values.length - 1) * .95).round()],
      'maxMs': values.last,
      'over16_67Ms': values.where((value) => value > 1000 / 60).length,
      'samplesMs': values,
    };
  }

  static Future<void> _flush(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1100)));
  }
}
