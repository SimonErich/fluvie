import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

const _color = Color(0xFF2ECC8F);

List<TimelineTrack> _nested() => const [
  TimelineTrack(id: 'top', label: 'Top'),
  TimelineTrack(id: 'g', label: 'Group', isGroup: true),
  TimelineTrack(id: 'c1', label: 'Child 1', depth: 1),
  TimelineTrack(id: 'sub', label: 'Subgroup', depth: 1, isGroup: true),
  TimelineTrack(id: 'sc', label: 'Sub child', depth: 2),
  TimelineTrack(id: 'tail', label: 'Tail'),
];

void main() {
  group('zoom', () {
    test('defaults to four pixels per frame and clamps to the range', () {
      final controller = TrackTimelineController();
      addTearDown(controller.dispose);
      expect(controller.pixelsPerFrame, 4);
      controller.pixelsPerFrame = 1000;
      expect(controller.pixelsPerFrame, TrackTimelineController.maxPixelsPerFrame);
      controller.pixelsPerFrame = 0.001;
      expect(controller.pixelsPerFrame, TrackTimelineController.minPixelsPerFrame);
    });

    test('zoomIn and zoomOut step by a quarter and notify', () {
      final controller = TrackTimelineController();
      addTearDown(controller.dispose);
      var notified = 0;
      controller
        ..addListener(() => notified++)
        ..zoomIn();
      expect(controller.pixelsPerFrame, closeTo(5, 1e-9));
      controller.zoomOut();
      expect(controller.pixelsPerFrame, closeTo(4, 1e-9));
      expect(notified, 2);
    });

    test('setting the same zoom does not notify', () {
      final controller = TrackTimelineController(pixelsPerFrame: 2);
      addTearDown(controller.dispose);
      var notified = 0;
      controller
        ..addListener(() => notified++)
        ..pixelsPerFrame = 2;
      expect(notified, 0);
    });

    test('zoomedScroll keeps the frame under the cursor stationary', () {
      // Frame under the cursor: (scrollX + cursorDx) / from = (120 + 80) / 4 = 50.
      final scrolled = TrackTimelineController.zoomedScroll(
        scrollX: 120,
        cursorDx: 80,
        from: 4,
        to: 8,
      );
      // At the new zoom, frame 50 sits at 400px; the cursor is still at 80.
      expect(scrolled, 320);
      expect((scrolled + 80) / 8, 50);
    });

    test('zoomedScroll never goes negative', () {
      final scrolled = TrackTimelineController.zoomedScroll(
        scrollX: 10,
        cursorDx: 40,
        from: 4,
        to: 1,
      );
      expect(scrolled, 0);
    });
  });

  group('collapse', () {
    test('toggleCollapsed flips membership and notifies', () {
      final controller = TrackTimelineController();
      addTearDown(controller.dispose);
      var notified = 0;
      controller
        ..addListener(() => notified++)
        ..toggleCollapsed('g');
      expect(controller.isCollapsed('g'), isTrue);
      expect(controller.collapsed, {'g'});
      controller.toggleCollapsed('g');
      expect(controller.isCollapsed('g'), isFalse);
      expect(notified, 2);
    });

    test('visibleTracks hides everything under a collapsed group', () {
      final visible = TrackTimelineController.visibleTracks(_nested(), {'g'});
      expect(visible.map((t) => t.id), ['top', 'g', 'tail']);
    });

    test('visibleTracks hides only the collapsed subgroup subtree', () {
      final visible = TrackTimelineController.visibleTracks(_nested(), {'sub'});
      expect(visible.map((t) => t.id), ['top', 'g', 'c1', 'sub', 'tail']);
    });

    test('visibleTracks shows every track when nothing is collapsed', () {
      final visible = TrackTimelineController.visibleTracks(_nested(), const {});
      expect(visible.length, 6);
    });

    test('a collapsed non-group id hides nothing', () {
      final visible = TrackTimelineController.visibleTracks(_nested(), {'c1'});
      expect(visible.length, 6);
    });
  });

  group('bars carry their own value semantics', () {
    test('equal bars compare equal', () {
      const a = TimelineBar(id: 'b', start: 10, end: 40, color: _color);
      const b = TimelineBar(id: 'b', start: 10, end: 40, color: _color);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.durationFrames, 30);
      expect(a.toString(), contains('b'));
    });

    test('tracks report their bars and flags', () {
      const track = TimelineTrack(
        id: 't',
        label: 'Track',
        bars: [TimelineBar(id: 'b', start: 0, end: 10, color: _color, badge: 'fadeIn')],
      );
      expect(track.isGroup, isFalse);
      expect(track.depth, 0);
      expect(track.bars.single.badge, 'fadeIn');
      expect(track.toString(), contains('Track'));
    });
  });
}
