@Tags(['golden'])
library;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart'
    show
        OiDensity,
        OiDensityScope,
        OiInputModality,
        OiPlatform,
        OiPlatformData,
        OiThemeData,
        OiThemeScope;

const _enter = Color(0xFF46A758);
const _link = Color(0xFF6E8BFF);

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
        child: SizedBox(width: 620, height: 160, child: child),
      ),
    ),
  ),
);

/// Two linked bars — the caption chains off the hero's end through an elbow
/// connector carrying its offset — under two build markers on the ruler,
/// with the caption bar flagged as violating (a red outline and underline).
Widget _linksAndMarkers() => _frame(
  const TrackTimeline(
    tracks: [
      TimelineTrack(
        id: 'hero',
        label: 'Hero',
        bars: [TimelineBar(id: 'hero-0', start: 10, end: 60, color: _enter, badge: 'fadeIn')],
      ),
      TimelineTrack(
        id: 'caption',
        label: 'Caption',
        bars: [
          TimelineBar(
            id: 'caption-0',
            start: 80,
            end: 110,
            color: _enter,
            badge: 'slideInUp',
            violation: true,
          ),
        ],
      ),
    ],
    links: [
      TimelineLink(
        id: 'caption-0',
        fromBarId: 'caption-0',
        toBarId: 'hero-0',
        toEdge: TimelineLinkEdge.end,
        color: _link,
        label: '+20f',
      ),
    ],
    markers: [
      TimelineMarker(id: 'step:0', frame: 60, label: '2'),
      TimelineMarker(id: 'step:1', frame: 110, label: '3'),
    ],
    selection: TrackTimelineSelection(
      selectedMarkerId: 'step:0',
    ),
    fps: 30,
    totalFrames: 120,
    playhead: 30,
  ),
);

Future<void> main() async {
  await goldenTest(
    'trigger links and build markers ride the timeline',
    fileName: 'track_timeline_links',
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        GoldenTestScenario(
          name: 'a linked pair, step markers, and a violating bar',
          child: _linksAndMarkers(),
        ),
      ],
    ),
  );
}
