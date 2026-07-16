import 'dart:collection';
import 'dart:convert';

import 'package:fluvie/fluvie.dart' show Video, VideoSpec, introspectTimeline;
import 'package:fluvie_editor/src/document/editor_document.dart';

/// One slide, derived and ready to mount: its single-scene [video] and the
/// frame where every entrance has settled.
final class DerivedSlide {
  DerivedSlide._(this.video, this.settleFrame);

  /// A single-scene composition sized and paced like the deck.
  final Video video;

  /// The first frame at which every entrance animation has finished — the
  /// still an editing canvas holds.
  final int settleFrame;
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
    final video = VideoSpec(
      scenes: [spec.scenes[slide]],
      size: spec.size,
      fps: spec.fps,
      motionDefaults: spec.motionDefaults,
      anchors: spec.anchors,
    ).build();
    final introspection = introspectTimeline(video);
    var settle = 0;
    for (final element in introspection.elements) {
      final enter = element.enterSpan;
      if (enter != null && enter.end > settle) settle = enter.end;
    }
    final derived = DerivedSlide._(video, settle);
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
      'scene': document.sceneJson(slide),
    });
  }
}
