import 'package:flutter/widgets.dart';
import 'package:fluvie_editor/src/shell/editor_workspace.dart';
import 'package:fluvie_editor/src/shell/inspector_tab_request.dart';
import 'package:fluvie_editor/src/shell/inspector_tab_strip.dart';
import 'package:obers_ui/obers_ui.dart';

/// The right column's tabs.
///
/// Each names a surface the editor either has or is about to have. A tab with
/// nothing behind it yet says in one line what will fill it and offers the
/// nearest thing that already works — empty is never a dead end, and an author
/// who opens Colour before grading exists should learn where grading will be,
/// not meet a blank panel.
enum InspectorTab {
  /// The element and slide inspector.
  inspector('Inspector'),

  /// The per-element effect stack.
  effects('Effects'),

  /// Grading.
  colour('Colour'),

  /// The mix.
  audio('Audio'),

  /// The element's animation list.
  animation('Animation');

  const InspectorTab(this.label);

  /// What the tab strip calls it.
  final String label;

  /// The workspace that raises this tab to the front, or null for the tabs no
  /// workspace owns.
  EditorWorkspace? get workspace => switch (this) {
    InspectorTab.colour => EditorWorkspace.colour,
    InspectorTab.audio => EditorWorkspace.audio,
    _ => null,
  };
}

/// The right column: a tab strip over whichever surface is selected.
///
/// The tab a workspace owns is raised when that workspace is picked, so
/// choosing Colour puts grading in front without the author hunting for it.
/// Quick shows only the inspector: the other tabs are depth, and depth is what
/// Quick is for hiding.
final class InspectorTabs extends StatefulWidget {
  /// Shows [inspector] under the Inspector tab, with [panels] for any tab that
  /// already has a surface.
  const InspectorTabs({
    required this.inspector,
    this.panels = const {},
    this.initialTab = InspectorTab.inspector,
    this.request,
    super.key,
  });

  /// The existing inspector, always behind the first tab.
  final Widget inspector;

  /// The surfaces that exist so far, by tab. A tab absent here shows its
  /// placeholder.
  final Map<InspectorTab, Widget> panels;

  /// Which tab opens first.
  final InspectorTab initialTab;

  /// An explicit navigation request from a timeline curve or other surface.
  final InspectorTabRequest? request;

  @override
  State<InspectorTabs> createState() => _InspectorTabsState();
}

final class _InspectorTabsState extends State<InspectorTabs> {
  late InspectorTab _tab = widget.request?.tab ?? widget.initialTab;
  EditorWorkspace? _workspace;

  @override
  void didUpdateWidget(InspectorTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.request != oldWidget.request && widget.request != null) _tab = widget.request!.tab;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final workspace = WorkspaceScope.of(context);
    if (_workspace == workspace) return;
    _workspace = workspace;
    // A workspace raises its tab once. Subsequent explicit picks belong to
    // the author, including moving back to Inspector without leaving Colour.
    final owned = InspectorTab.values.where((tab) => tab.workspace == workspace).firstOrNull;
    if (owned != null) _tab = owned;
  }

  /// The tabs this workspace offers.
  ///
  /// Quick keeps only the inspector; every other workspace offers all of them,
  /// because taking a tab away would hide work rather than simplify it.
  List<InspectorTab> _visible(EditorWorkspace workspace) =>
      workspace == EditorWorkspace.quick ? const [InspectorTab.inspector] : InspectorTab.values;

  @override
  Widget build(BuildContext context) {
    final workspace = WorkspaceScope.of(context);
    final tabs = _visible(workspace);
    // A workspace that owns a tab raises it; otherwise the author's own pick
    // stands, falling back to the inspector when their pick is not on offer.
    final active = tabs.contains(_tab) ? _tab : InspectorTab.inspector;
    // Bound the content independently from the intrinsic-width tab strip.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InspectorTabStrip(
          tabs: tabs,
          selected: active,
          onSelected: (tab) => setState(() => _tab = tab),
        ),
        Expanded(child: widget.panels[active] ?? _surfaceFor(active)),
      ],
    );
  }

  Widget _surfaceFor(InspectorTab tab) =>
      tab == InspectorTab.inspector ? widget.inspector : InspectorTabPlaceholder(tab: tab);
}

/// What a tab shows before its surface exists: one line on what will fill it.
final class InspectorTabPlaceholder extends StatelessWidget {
  /// Describes [tab].
  const InspectorTabPlaceholder({required this.tab, super.key});

  /// The tab with nothing behind it yet.
  final InspectorTab tab;

  /// One line saying what will fill this tab.
  static String noteFor(InspectorTab tab) => switch (tab) {
    InspectorTab.inspector => 'Select something on the canvas to edit it.',
    InspectorTab.effects => 'Effects on the selected element will stack here.',
    InspectorTab.colour => 'Exposure, contrast and grading will live here.',
    InspectorTab.audio => 'Levels and fades for the mix will live here.',
    InspectorTab.animation => "The selected element's animations will list here.",
  };

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: OiLabel.small(noteFor(tab), color: context.colors.textMuted),
  );
}
