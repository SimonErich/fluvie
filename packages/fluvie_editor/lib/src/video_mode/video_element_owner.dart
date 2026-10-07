import 'package:fluvie/fluvie.dart' show FrameSpan, TimelineIntrospection;
import 'package:fluvie_editor/src/document/editor_document.dart';

/// The nearest enclosing time scope, skipping structural groups that introduce
/// no window. Shared by trim/split/speed so a group never changes the edit clock.
FrameSpan videoElementOwner(EditorDocument document, TimelineIntrospection timeline, String id) {
  var parent = document.parentGroupOf(id);
  while (parent != null) {
    final window = timeline.elementById(parent)?.window;
    if (window != null) return window;
    parent = document.parentGroupOf(parent);
  }
  final scene = document.sceneOfElement(id);
  return scene == null ? FrameSpan(0, timeline.totalFrames) : timeline.scenes[scene].span;
}
