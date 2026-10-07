part of 'slide_timeline_model.dart';

/// Accumulates tracks and bindings for one slide.
final class _ModelBuilder {
  _ModelBuilder(
    this.document,
    this.sceneStart,
    this.sceneFrames,
    this.palette,
    this.introspect,
    this.steppedIds,
  );

  final EditorDocument document;
  final int sceneStart;
  final int sceneFrames;
  final TimelinePhasePalette palette;
  final ElementIntrospection? Function(String id) introspect;
  final Set<String> steppedIds;
  final AnchorTable anchors = AnchorTable();
  final List<TimelineTrack> tracks = [];
  final Map<String, TimelineBarBinding> bindings = {};
  final Map<String, TimelineDiamondBinding> diamondBindings = {};
  final List<_BarFacts> facts = [];
  final Map<String, String> anchorOf = {};

  void addTrack(String id, {required int depth}) {
    final json = document.elementJson(id) ?? const {};
    if (json['anchor'] case final String anchor) anchorOf[id] = anchor;
    tracks.add(
      TimelineTrack(
        id: id,
        label: _label(id, json),
        depth: depth,
        isGroup: json['type'] == 'Group',
        bars: _bars(id, json),
      ),
    );
  }

  String _label(String id, Map<String, Object?> json) {
    final name = document.elementMeta(id)['name'];
    if (name is String && name.isNotEmpty) return name;
    return json['type'] as String? ?? id;
  }

  List<TimelineBar> _bars(String id, Map<String, Object?> json) {
    final element = introspect(id);
    final animate = json['animate'];
    final bars = <TimelineBar>[];
    if (element != null && animate is List) _animateBars(id, element, animate, bars);
    final reveal = revealBar(id, json, element);
    if (reveal != null) bars.add(reveal);
    return bars;
  }

  /// The phase-colored bars from the element's `animate` entries, joined back
  /// to the document through a [TimelineBarBinding] each so the panel can
  /// retime and trim them.
  void _animateBars(
    String id,
    ElementIntrospection element,
    List<Object?> animate,
    List<TimelineBar> bars,
  ) {
    final count = element.animations.length;
    for (var i = 0; i < count && i < animate.length; i++) {
      final animation = element.animations[i];
      final animationJson = animate[i]! as Map<String, Object?>;
      final spec = AnimationSpec.fromJson(animationJson, anchors);
      final barId = '$id:$i';
      final start = (animation.span.start - sceneStart).toDouble();
      final end = (animation.span.end - sceneStart).toDouble();
      final stopFrames = keyframeStopFrames(
        animationJson,
        spanFrames: animation.span.durationFrames,
        fps: document.spec.fps,
      );
      final delayFrames = spec.delay?.resolveFrames(_WindowScope(document.spec.fps, element)) ?? 0;
      bars.add(
        TimelineBar(
          id: barId,
          start: start,
          end: end,
          color: switch (animation.phase) {
            AnimationPhase.enter => palette.enter,
            AnimationPhase.during => palette.during,
            AnimationPhase.exit => palette.exit,
          },
          easing: spec.ease ?? Ease.smooth,
          badge: spec.label ?? spec.kind,
          violation: steppedIds.contains(id) && _isCompositionTrigger(animationJson['at']),
          diamonds: [
            if (stopFrames != null)
              for (var s = 0; s < stopFrames.length; s++)
                TimelineDiamond(id: '$barId:k$s', frame: start + stopFrames[s]),
          ],
        ),
      );
      bindings[barId] = TimelineBarBinding(
        elementId: id,
        index: i,
        delayFrames: delayFrames,
        durationFrames: animation.span.durationFrames,
        stopFrames: stopFrames,
      );
      facts.add(
        _BarFacts(
          barId: barId,
          elementId: id,
          index: i,
          at: animationJson['at'],
          delayFrames: delayFrames,
          start: start,
          end: end,
        ),
      );
      if (stopFrames != null) {
        for (var s = 0; s < stopFrames.length; s++) {
          diamondBindings['$barId:k$s'] = TimelineDiamondBinding(barId: barId, stop: s);
        }
      }
    }
  }
}
