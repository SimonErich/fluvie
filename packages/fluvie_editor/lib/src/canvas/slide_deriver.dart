import 'dart:collection';
import 'dart:convert';

import 'package:fluvie/fluvie.dart' show ElementSpec, Video, VideoSpec, introspectTimeline;
import 'package:fluvie_editor/src/document/editor_document.dart';

/// One slide, derived and ready to mount: its single-scene [video], the
/// frame where every entrance has settled, and its length in frames.
final class DerivedSlide {
  DerivedSlide._(this.video, this.settleFrame, this.totalFrames);

  /// A single-scene composition sized and paced like the deck.
  final Video video;

  /// The first frame at which every entrance animation has finished — the
  /// still an editing canvas holds.
  final int settleFrame;

  /// The slide's resolved length in frames — the bound its transport plays
  /// to.
  final int totalFrames;
}

/// Derives slides from the document, memoized by slide content.
///
/// The cache key is the slide's own JSON plus the deck-level keys that
/// change its rendering, so editing one slide never re-derives the others,
/// and a rename (editor metadata) re-derives nothing at all.
final class SlideDeriver {
  /// Creates the deriver with room for [capacity] derived slides.
  SlideDeriver({this.capacity = 16}) : assert(capacity > 0, 'capacity must be > 0');

  /// How many derived slides stay warm before the least recent is evicted.
  final int capacity;

  final LinkedHashMap<String, DerivedSlide> _cache = LinkedHashMap();

  /// The derived slide for scene [slide] of [document].
  DerivedSlide derive(EditorDocument document, int slide) {
    final key = _key(document, slide);
    final cached = _cache.remove(key);
    if (cached != null) return _cache[key] = cached;

    final spec = document.spec;
    // The overlays homed on this slide come along, so the canvas shows what
    // the frame will actually look like. Their windows are the video's, and
    // this stage is one slide long, so each one is stripped to a plain
    // element: the point here is what it looks like, not when it is alive.
    final homed = document.overlaysHomedOn(slide);
    final video = VideoSpec(
      scenes: [spec.scenes[slide]],
      overlays: [
        for (final overlay in spec.overlays)
          if (homed.contains(overlay.id)) _unwindowed(overlay),
      ],
      size: spec.size,
      fps: spec.fps,
      motionDefaults: spec.motionDefaults,
      theme: spec.theme,
      masters: spec.masters,
      anchors: spec.anchors,
    ).build();
    final introspection = introspectTimeline(video);
    var settle = 0;
    for (final element in introspection.elements) {
      final enter = element.enterSpan;
      if (enter != null && enter.end > settle) settle = enter.end;
    }
    final derived = DerivedSlide._(video, settle, introspection.scenes.first.span.durationFrames);
    _cache[key] = derived;
    while (_cache.length > capacity) {
      _cache.remove(_cache.keys.first);
    }
    return derived;
  }

  String _key(EditorDocument document, int slide) {
    final json = document.toJson();
    return jsonEncode({
      'size': json['size'],
      'fps': json['fps'],
      'motionDefaults': json['motionDefaults'],
      'theme': json['theme'],
      'masters': json['masters'],
      'scene': document.sceneJson(slide),
      'overlays': [
        for (final id in document.overlaysHomedOn(slide)) document.elementJson(id),
      ],
    });
  }
}

/// [overlay] with its window dropped.
///
/// The canvas stage is one slide long and an overlay's window is the whole
/// video's, so a window carried over would gate the element out of a stage it
/// is supposed to be drawn on. The timeline is where an overlay's timing is
/// read; the canvas is where its geometry is.
ElementSpec _unwindowed(ElementSpec overlay) => ElementSpec(
  type: overlay.type,
  props: overlay.props,
  id: overlay.id,
  placement: overlay.placement,
  anchor: overlay.anchor,
  visible: overlay.visible,
  animate: overlay.animate,
  lane: overlay.lane,
);
