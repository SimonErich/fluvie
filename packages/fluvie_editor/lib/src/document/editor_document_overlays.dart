part of 'editor_document.dart';

/// The overlays: elements that belong to no slide and run the whole video.
///
/// Which slide the editor *draws* an overlay on is editorial, not
/// render-affecting, so it lives in the `editor` block under `overlayHomes`
/// and never moves the content digest. Everything else about an overlay — its
/// window, its transform, its props — is spec data like any element's.
extension EditorDocumentOverlays on EditorDocument {
  /// The overlay ids, in declaration order (which is paint order).
  List<String> get overlayIds => [
    for (final overlay in _overlayJson(_json))
      if (overlay['id'] case final String id) id,
  ];

  /// Whether [id] names an overlay rather than a slide's element.
  bool isOverlay(String id) => overlayIds.contains(id);

  /// The slide the editor draws overlay [id] on, or null when it has no home
  /// yet (a fresh overlay drawn nowhere until something homes it).
  int? overlayHome(String id) {
    final home = _overlayHomes[id];
    if (home is! int) return null;
    return home.clamp(0, sceneCount - 1);
  }

  /// The overlay ids homed on slide [slide], in declaration order.
  List<String> overlaysHomedOn(int slide) => [
    for (final id in overlayIds)
      if (overlayHome(id) == slide) id,
  ];

  /// This document with overlay [id] homed on [slide].
  EditorDocument withOverlayHome(String id, int slide) {
    final json = _deepCopy(_json);
    final editor =
        (json['editor'] ??= <String, Object?>{'editorSchema': 1}) as Map<String, Object?>;
    final homes = (editor['overlayHomes'] ??= <String, Object?>{}) as Map<String, Object?>;
    homes[id] = slide;
    return EditorDocument._(json);
  }

  Map<String, Object?> get _overlayHomes {
    final editor = _json['editor'];
    if (editor is! Map<String, Object?>) return const {};
    final homes = editor['overlayHomes'];
    return homes is Map<String, Object?> ? homes : const {};
  }

  /// This document with [element] appended to the overlays.
  EditorDocument addOverlay(Map<String, Object?> element) {
    final json = _deepCopy(_json);
    ((json['overlays'] ??= <Object?>[]) as List<Object?>).add(_deepCopy(element));
    return EditorDocument._(json);
  }

  /// This document without overlay [id], and without its home.
  ///
  /// The key goes with the element: a home pointing at nothing would be read
  /// back as an overlay drawn on a slide that has none.
  EditorDocument removeOverlay(String id) {
    final json = _deepCopy(_json);
    final overlays = json['overlays'];
    if (overlays is List) {
      overlays.removeWhere((o) => o is Map<String, Object?> && o['id'] == id);
      if (overlays.isEmpty) json.remove('overlays');
    }
    final editor = json['editor'];
    if (editor is Map<String, Object?>) {
      final homes = editor['overlayHomes'];
      if (homes is Map<String, Object?> && homes.remove(id) != null && homes.isEmpty) {
        editor.remove('overlayHomes');
      }
    }
    return EditorDocument._(json);
  }
}
