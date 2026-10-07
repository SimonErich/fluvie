@Tags(['golden'])
library;

import 'dart:math' as math;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/rendering.dart' show WaveformBucket, WaveformEnvelope;
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart'
    show
        OiButton,
        OiDensity,
        OiDensityScope,
        OiInputModality,
        OiPlatform,
        OiPlatformData,
        OiThemeData,
        OiThemeScope;

// The phase palette the domain binding uses: entrances green, ambient
// emphasis amber, exits red.
const _enter = Color(0xFF46A758);
const _during = Color(0xFFFFB224);
const _exit = Color(0xFFE5484D);

Widget _frame(Widget child) => OiThemeScope(
  data: OiThemeData.dark(),
  child: OiPlatform(
    data: const OiPlatformData(
      platform: TargetPlatform.linux,
      keyboardHeight: 0,
      keyboardVisible: false,
      inputModality: OiInputModality.pointer,
    ),
    child: OiDensityScope(
      density: OiDensity.compact,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(width: 620, height: 220, child: child),
      ),
    ),
  ),
);

/// A populated slide: phase-colored bars with easing sketches and badges,
/// the playhead mid-slide, and a collapsed group row.
Widget _populated() {
  final controller = TrackTimelineController(pixelsPerFrame: 1.8)..toggleCollapsed('grp');
  return _frame(
    TrackTimeline(
      tracks: const [
        TimelineTrack(
          id: 'title',
          label: 'Title',
          bars: [
            TimelineBar(
              id: 'title-0',
              start: 0,
              end: 45,
              color: _enter,
              easing: Curves.easeOutBack,
              badge: 'slideIn',
            ),
            TimelineBar(
              id: 'title-1',
              start: 200,
              end: 240,
              color: _exit,
              easing: Curves.easeIn,
              badge: 'fadeOut',
            ),
          ],
        ),
        TimelineTrack(
          id: 'subtitle',
          label: 'Subtitle',
          bars: [
            TimelineBar(
              id: 'subtitle-0',
              start: 20,
              end: 65,
              color: _enter,
              easing: Curves.easeInOut,
              badge: 'fadeIn',
            ),
            TimelineBar(
              id: 'subtitle-1',
              start: 65,
              end: 200,
              color: _during,
              easing: Curves.linear,
              badge: 'float',
            ),
          ],
        ),
        TimelineTrack(id: 'grp', label: 'Diagram', isGroup: true),
        TimelineTrack(id: 'grp-child', label: 'Callout', depth: 1),
        TimelineTrack(
          id: 'chart',
          label: 'Chart',
          bars: [
            TimelineBar(
              id: 'chart-0',
              start: 90,
              end: 150,
              color: _enter,
              easing: Curves.easeOutCubic,
              badge: 'pop',
            ),
          ],
        ),
      ],
      fps: 30,
      totalFrames: 240,
      playhead: 120,
      controller: controller,
    ),
  );
}

/// A selected track: the row fills with the accent wash and its label tints,
/// the canvas-to-timeline highlight.
Widget _selected() {
  final controller = TrackTimelineController(pixelsPerFrame: 1.8);
  return _frame(
    TrackTimeline(
      tracks: const [
        TimelineTrack(
          id: 'title',
          label: 'Title',
          bars: [
            TimelineBar(
              id: 'title-0',
              start: 0,
              end: 45,
              color: _enter,
              easing: Curves.easeOutBack,
              badge: 'slideIn',
            ),
          ],
        ),
        TimelineTrack(
          id: 'subtitle',
          label: 'Subtitle',
          bars: [
            TimelineBar(id: 'subtitle-0', start: 20, end: 65, color: _enter, badge: 'fadeIn'),
          ],
        ),
        TimelineTrack(id: 'counter', label: 'Counter'),
      ],
      fps: 30,
      totalFrames: 240,
      playhead: 120,
      controller: controller,
      selection: const TrackTimelineSelection(
        selectedTrackIds: {'subtitle'},
      ),
    ),
  );
}

/// A tall audio lane over its own waveform, beside a short video lane: the
/// envelope reads as loudness behind the bars, and a lane sets its own height
/// because a waveform needs room a bar does not.
Widget _waveform() {
  final controller = TrackTimelineController(pixelsPerFrame: 1.8);
  final envelope = WaveformEnvelope(
    buckets: [
      for (var i = 0; i < 120; i++)
        WaveformBucket(
          min: -_level(i),
          max: _level(i),
          rms: _level(i) * 0.7,
        ),
    ],
    sampleRate: 48000,
    durationSeconds: 8,
  );
  return _frame(
    TrackTimeline(
      tracks: [
        const TimelineTrack(
          id: 'v1',
          label: 'Video 1',
          bars: [TimelineBar(id: 'v1-0', start: 0, end: 140, color: _enter)],
        ),
        TimelineTrack(
          id: 'a1',
          label: 'bed.mp3',
          height: 56,
          envelope: envelope,
          bars: const [TimelineBar(id: 'a1-0', start: 0, end: 240, color: _during)],
        ),
      ],
      fps: 30,
      totalFrames: 240,
      playhead: 120,
      controller: controller,
    ),
  );
}

/// A shape with a quiet opening, a loud middle and a fade, so the drawing has
/// something to say rather than a flat band.
double _level(int bucket) {
  final t = bucket / 120;
  return (0.25 + 0.75 * math.sin(t * math.pi)) * (0.6 + 0.4 * math.sin(bucket * 1.7));
}

/// Selected bars: each takes a bright outline, whatever lane it sits on and
/// whatever its own colour is.
Widget _selectedBars() {
  final controller = TrackTimelineController(pixelsPerFrame: 1.8);
  return _frame(
    TrackTimeline(
      tracks: const [
        TimelineTrack(
          id: 'v1',
          label: 'Video 1',
          bars: [
            TimelineBar(id: 'v1-0', start: 0, end: 90, color: _enter),
            TimelineBar(id: 'v1-1', start: 100, end: 160, color: _during),
          ],
        ),
        TimelineTrack(
          id: 'v2',
          label: 'Video 2',
          bars: [TimelineBar(id: 'v2-0', start: 40, end: 140, color: _exit)],
        ),
      ],
      fps: 30,
      totalFrames: 240,
      playhead: 120,
      selection: const TrackTimelineSelection(
        selectedBarIds: {'v1-1', 'v2-0'},
      ),
      controller: controller,
    ),
  );
}

/// A drag caught on a snap: the guide sits under the playhead, so the two
/// lines stay tellable apart when a drag lands right on the playhead.
Widget _snapping() {
  final controller = TrackTimelineController(pixelsPerFrame: 1.8);
  return _frame(
    TrackTimeline(
      tracks: const [
        TimelineTrack(
          id: 'v1',
          label: 'Video 1',
          bars: [TimelineBar(id: 'v1-0', start: 0, end: 90, color: _enter)],
        ),
        TimelineTrack(
          id: 'v2',
          label: 'Video 2',
          bars: [TimelineBar(id: 'v2-0', start: 90, end: 180, color: _during)],
        ),
        TimelineTrack(id: 'v3', label: 'Video 3'),
      ],
      fps: 30,
      totalFrames: 240,
      playhead: 120,
      snapFrame: 90,
      controller: controller,
    ),
  );
}

/// The empty state: one line plus the add-animation action slot.
Widget _empty() => _frame(
  TrackTimeline(
    tracks: const [],
    fps: 30,
    totalFrames: 240,
    appearance: TrackTimelineAppearance(
      emptyMessage: 'No animations on this slide yet.',
      emptyAction: OiButton.secondary(label: 'Add an animation', onTap: () {}),
    ),
  ),
);

Future<void> main() async {
  await goldenTest(
    'the track timeline shows phase bars and explains emptiness',
    fileName: 'track_timeline',
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        GoldenTestScenario(name: 'a populated slide with a collapsed group', child: _populated()),
        GoldenTestScenario(name: 'a selected track fills its row and label', child: _selected()),
        GoldenTestScenario(name: 'selected bars outline themselves', child: _selectedBars()),
        GoldenTestScenario(name: 'an audio lane draws its own waveform', child: _waveform()),
        GoldenTestScenario(name: 'a drag caught on a snap guide', child: _snapping()),
        GoldenTestScenario(name: 'the empty state offers an action', child: _empty()),
      ],
    ),
  );
}
