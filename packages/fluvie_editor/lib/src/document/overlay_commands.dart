part of 'editor_command.dart';

/// Moves element [id] out of its slide and into the video's overlays, homed on
/// the slide it came from.
///
/// The bar does not move a pixel: a slide-relative window is rewritten to the
/// absolute frames it already occupied, because an overlay's window is
/// measured against the whole video. Everything else about the element — its
/// transform, its props, its animations — is untouched.
final class MakeOverlayCommand extends EditorCommand {
  /// Promotes [id] to an overlay, holding its absolute window.
  ///
  /// [sceneStart] is the absolute frame its slide begins on, and [sceneFrames]
  /// that slide's length, so a window with no explicit bound resolves to the
  /// frames the element was actually alive for.
  const MakeOverlayCommand({
    required this.id,
    required this.sceneStart,
    required this.sceneFrames,
  });

  /// The element being promoted.
  final String id;

  /// The absolute frame its slide starts on.
  final int sceneStart;

  /// Its slide's length in frames.
  final int sceneFrames;

  @override
  EditorDocument apply(EditorDocument document) {
    final element = document.elementJson(id);
    final scene = document.sceneOfElement(id);
    if (element == null || scene == null) return document;
    final window = _windowFrames(element, sceneFrames);
    final promoted = {
      ...element,
      'show': {
        'from': '${sceneStart + window.from}f',
        'to': '${sceneStart + window.to}f',
      },
    };
    return document.removeElement(id).addOverlay(promoted).withOverlayHome(id, scene);
  }

  @override
  String get label => 'Make $id global';

  @override
  Set<String> get affectedIds => {id};
}

/// Moves overlay [id] back into a slide, rewriting its absolute window to that
/// slide's frames.
///
/// The bar does not move a pixel either way. A window that straddles a
/// boundary is clamped into the slide it lands in and the caller says so:
/// there is no honest way to keep a slide-local element alive past its slide.
final class MakeSceneLocalCommand extends EditorCommand {
  /// Demotes overlay [id] into slide [scene], whose absolute span is
  /// [sceneStart] to `sceneStart + sceneFrames`.
  const MakeSceneLocalCommand({
    required this.id,
    required this.scene,
    required this.sceneStart,
    required this.sceneFrames,
  });

  /// The overlay being demoted.
  final String id;

  /// The slide receiving it.
  final int scene;

  /// That slide's absolute start frame.
  final int sceneStart;

  /// That slide's length in frames.
  final int sceneFrames;

  @override
  EditorDocument apply(EditorDocument document) {
    final element = document.elementJson(id);
    if (element == null || !document.isOverlay(id)) return document;
    final window = _windowFrames(element, sceneStart + sceneFrames);
    final from = (window.from - sceneStart).clamp(0, sceneFrames - 1);
    final to = (window.to - sceneStart).clamp(from + 1, sceneFrames);
    final demoted = {
      ...element,
      'show': {'from': '${from}f', 'to': '${to}f'},
    };
    return document.removeOverlay(id).insertElement(scene, demoted).$1;
  }

  @override
  String get label => 'Make $id slide-local';

  @override
  Set<String> get affectedIds => {id};
}

/// [element]'s window in frames, defaulting a missing bound to the span it
/// lives in: a window with no `from` starts at zero and one with no `to` runs
/// to the end of whatever holds it.
({int from, int to}) _windowFrames(Map<String, Object?> element, int spanFrames) {
  final show = element['show'];
  if (show is! Map<String, Object?>) return (from: 0, to: spanFrames);
  return (from: _frameValue(show['from']) ?? 0, to: _frameValue(show['to']) ?? spanFrames);
}

/// A `<n>f` time in frames, or null for any other unit.
int? _frameValue(Object? raw) {
  if (raw is! String || !raw.endsWith('f')) return null;
  return int.tryParse(raw.substring(0, raw.length - 1));
}
