part of 'editor_command.dart';

/// Toggles a slide's auto-animate: on runs the pairing engine against the
/// previous slide and writes the `shared` ids it minted (re-running on an
/// already-on slide refreshes stale pairings the same way); off removes
/// exactly what on added, author-typed shared ids untouched. One undo step
/// either way.
final class ApplyAutoAnimateCommand extends EditorCommand {
  /// Applies ([enabled]) or clears auto-animate on [slide].
  const ApplyAutoAnimateCommand({required this.slide, required this.enabled});

  /// The slide whose boundary into the previous slide is auto-animated.
  final int slide;

  /// Whether the switch lands on or off.
  final bool enabled;

  @override
  EditorDocument apply(EditorDocument document) =>
      enabled ? document.applyAutoAnimate(slide) : document.clearAutoAnimate(slide);

  @override
  String get label => enabled ? 'Auto-animate slide ${slide + 1}' : 'Clear auto-animate';

  @override
  Set<String> get affectedIds => const {};
}

/// Manually pairs a current-slide element with a previous-slide element —
/// an author-level `shared` link that survives the auto-animate toggle.
final class LinkSharedCommand extends EditorCommand {
  /// Links [currentId] (on [slide]) to [previousId] (on the slide before).
  const LinkSharedCommand({
    required this.slide,
    required this.currentId,
    required this.previousId,
  });

  /// The slide holding the element being linked.
  final int slide;

  /// The element on [slide] gaining the pairing.
  final String currentId;

  /// The previous-slide element it morphs from.
  final String previousId;

  @override
  EditorDocument apply(EditorDocument document) =>
      document.linkShared(slide: slide, currentId: currentId, previousId: previousId);

  @override
  String get label => 'Link $currentId to the previous slide';

  @override
  Set<String> get affectedIds => {currentId};
}

/// Breaks an element's pairing into the previous slide. An auto-minted pair
/// dissolves on both sides; an author-typed id leaves only this element.
final class UnlinkSharedCommand extends EditorCommand {
  /// Unlinks [elementId] on [slide].
  const UnlinkSharedCommand({required this.slide, required this.elementId});

  /// The slide holding the element.
  final int slide;

  /// The element losing its pairing.
  final String elementId;

  @override
  EditorDocument apply(EditorDocument document) =>
      document.unlinkShared(slide: slide, elementId: elementId);

  @override
  String get label => 'Unlink $elementId';

  @override
  Set<String> get affectedIds => {elementId};
}
