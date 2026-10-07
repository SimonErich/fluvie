part of 'video_lane_model.dart';

/// Accumulates the video timeline's tracks and bindings.
final class _VideoLaneBuilder {
  _VideoLaneBuilder(this.document, this.timebase, this.introspection, this.palette);

  final EditorDocument document;
  final VideoTimebase timebase;
  final TimelineIntrospection introspection;
  final VideoLanePalette palette;
  final List<TimelineTrack> tracks = [];
  final List<TimelineMarker> markers = [];
  final Map<String, VideoElementLaneBinding> elementBars = {};
  final Map<String, VideoAudioLaneBinding> audioBars = {};
  final Map<String, VideoOverlayLaneBinding> overlayBars = {};
  final Map<String, VideoEffectLaneBinding> effectBars = {};
  final Map<String, VideoEffectDiamondBinding> effectDiamonds = {};
  final Map<String, VideoTransitionBinding> transitionBars = {};

  void build() {
    _scenesLane();
    _declaredLanes();
    _overlayLanes();
    for (var scene = 0; scene < timebase.sceneSpans.length; scene++) {
      final stepIds = _stepIdsOf(scene);
      for (final id in document.elementIdsInScene(scene).reversed) {
        _elementLane(id, scene, stepIds: stepIds);
        for (final childId in document.childIdsOfGroup(id).reversed) {
          _elementLane(childId, scene, stepIds: stepIds, grouped: true);
        }
      }
    }
    _collapseSharedChains();
    _transitionLanes();
    for (var index = 0; index < document.audioTracksJson().length; index++) {
      _audioLane(scene: null, index: index);
    }
    for (var scene = 0; scene < timebase.sceneSpans.length; scene++) {
      for (var index = 0; index < document.audioTracksJson(scene: scene).length; index++) {
        _audioLane(scene: scene, index: index);
      }
    }
  }
}
