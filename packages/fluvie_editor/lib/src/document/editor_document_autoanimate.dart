part of 'editor_document.dart';

/// The `enter` auto-animate writes when nothing governs the boundary — a
/// morph needs a blend window to play in.
const Map<String, Object?> _autoEnterJson = {'kind': 'crossFade', 'duration': '500ms'};

/// The auto-animate reads. The per-slide switch is editor metadata
/// (`editor.scenes.<i>.autoAnimate`); the *result* — `shared` ids on the
/// paired elements — is spec data, so an auto-animated deck morphs anywhere
/// the spec renders. The mutations live in [EditorDocumentAutoAnimateEdits].
extension EditorDocumentAutoAnimate on EditorDocument {
  /// Whether slide [slide] matches its elements to the previous slide.
  bool autoAnimateOn(int slide) => sceneMeta(slide)['autoAnimate'] == true;

  /// The pairing engine's view of the boundary into [slide]. Slide zero has
  /// no previous slide, so its previous side is empty.
  SharedPairing autoAnimatePairing(int slide) => pairElements(
    previous: slide == 0 ? const [] : _childrenJsonOf(slide - 1),
    current: _childrenJsonOf(slide),
  );

  /// The previous-slide element paired with [elementId] through a `shared`
  /// id, or null when [elementId] is unlinked (or [slide] is the first).
  String? sharedPartnerOf(int slide, String elementId) {
    if (slide == 0) return null;
    final shared = elementJson(elementId)?['shared'];
    if (shared is! String) return null;
    return _sharedCarrierIn(slide - 1, shared);
  }

  /// The previous-slide elements not yet claimed by any current-slide pair
  /// — what a manual "Link to previous slide element" picker offers.
  List<String> linkCandidatesOf(int slide) {
    if (slide == 0) return const [];
    final partnered = {
      for (final id in _walkIdsOf(slide)) sharedPartnerOf(slide, id),
    };
    return [
      for (final id in _walkIdsOf(slide - 1))
        if (!partnered.contains(id)) id,
    ];
  }

  /// How many current-slide elements hold a live pairing into the previous
  /// slide right now.
  int linkedPairCountOf(int slide) => [
    for (final id in _walkIdsOf(slide))
      if (sharedPartnerOf(slide, id) != null) id,
  ].length;

  /// The first element of scene [scene] carrying [shared], or null.
  String? _sharedCarrierIn(int scene, String shared) {
    for (final walked in _walkScene(_scene(scene))) {
      if (walked.element['shared'] == shared) return walked.element['id'] as String?;
    }
    return null;
  }

  /// Every element id of scene [scene], depth-first document order.
  List<String> _walkIdsOf(int scene) => [
    for (final walked in _walkScene(_scene(scene)))
      if (walked.element['id'] case final String id) id,
  ];

  /// The deep-copied top-level children JSON of scene [scene].
  List<Map<String, Object?>> _childrenJsonOf(int scene) {
    final children = sceneJson(scene)['children'];
    if (children is! List) return const [];
    return children.whereType<Map<String, Object?>>().toList();
  }
}
