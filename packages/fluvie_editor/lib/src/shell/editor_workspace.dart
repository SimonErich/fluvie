import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';

/// Which set of panels and how much of each the editor is showing.
///
/// A workspace is the reconciling mechanism between a beginner and a
/// professional in one UI: not a simple/advanced fork of the product, but one
/// disclosure level that every panel reads. **The document is identical either
/// side** — a workspace changes what is on screen and nothing else — so
/// switching mid-edit loses nothing and there is no cliff between them.
enum EditorWorkspace {
  /// The fewest controls that still make a video: three tools, the essential
  /// inspector rows, a short export.
  quick('Quick', DisclosureLevel.minimal),

  /// Everything the editor has, which is what an author who knows the tool
  /// wants in front of them.
  edit('Edit', DisclosureLevel.full),

  /// Grading raised to the front; the rest dimmed but reachable.
  colour('Colour', DisclosureLevel.full),

  /// The mix raised to the front.
  audio('Audio', DisclosureLevel.full),

  /// Export and delivery raised to the front.
  deliver('Deliver', DisclosureLevel.full);

  const EditorWorkspace(this.label, this.disclosure);

  /// What the control calls this workspace.
  final String label;

  /// How much every panel reading the scope should show.
  final DisclosureLevel disclosure;
}

/// How much of itself a panel shows.
///
/// Deliberately two values, not a number. A panel that branches on "how
/// advanced" invents its own scale and they drift; a panel that branches on
/// "everything or the essentials" cannot.
enum DisclosureLevel {
  /// The essentials only.
  minimal,

  /// Everything the panel has.
  full,
}

/// Publishes the active [EditorWorkspace] to every panel below.
///
/// One scope rather than a parameter threaded through the tree, because the
/// panels that read it are far apart and most of the widgets between them do
/// not care. A panel with no scope above it gets [EditorWorkspace.edit]: a host
/// that has not adopted workspaces sees the full editor, which is what it had.
final class WorkspaceScope extends InheritedWidget {
  /// Publishes [workspace] over [child].
  const WorkspaceScope({required this.workspace, required super.child, super.key});

  /// The active workspace.
  final EditorWorkspace workspace;

  /// The workspace above [context], or [EditorWorkspace.edit] where none is
  /// published.
  static EditorWorkspace of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WorkspaceScope>()?.workspace ??
      EditorWorkspace.edit;

  /// How much a panel below [context] should show.
  static DisclosureLevel disclosureOf(BuildContext context) => of(context).disclosure;

  @override
  bool updateShouldNotify(WorkspaceScope oldWidget) => oldWidget.workspace != workspace;
}

/// The control that picks a workspace.
final class WorkspaceControl extends StatelessWidget {
  /// Shows [workspace] as the active one and reports a pick to [onChanged].
  const WorkspaceControl({required this.workspace, required this.onChanged, super.key});

  /// The active workspace.
  final EditorWorkspace workspace;

  /// Receives the picked workspace.
  final ValueChanged<EditorWorkspace> onChanged;

  @override
  Widget build(BuildContext context) => OiSegmentedControl<EditorWorkspace>(
    selected: workspace,
    semanticLabel: 'Workspace',
    segments: [
      for (final candidate in EditorWorkspace.values)
        OiSegment(value: candidate, label: candidate.label),
    ],
    onChanged: onChanged,
  );
}
