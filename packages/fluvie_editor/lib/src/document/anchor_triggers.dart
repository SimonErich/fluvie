import 'package:fluvie/fluvie.dart' show FluvieTimingError, introspectTimeline;
import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';

/// A fresh anchor id for [targetId] in [document]: the element's own id,
/// suffixed past any collision with an already-declared anchor — what a
/// trigger link mints when its target has no anchor yet.
String mintedAnchorId(EditorDocument document, String targetId) {
  final used = document.anchorIds;
  if (!used.contains(targetId)) return targetId;
  var suffix = 2;
  while (used.contains('$targetId-$suffix')) {
    suffix++;
  }
  return '$targetId-$suffix';
}

/// Whether [document] still resolves after [command] — the cycle guard a
/// trigger write runs before dispatching (a `whenEnds` pointing back at its
/// own dependent would otherwise poison the deck).
bool resolvesAfter(EditorDocument document, EditorCommand command) {
  try {
    introspectTimeline(command.apply(document).spec.build());
    return true;
  } on FluvieTimingError {
    return false;
  }
}
