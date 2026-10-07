import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart';
import 'package:fluvie_editor/src/commands/command_scope.dart';
import 'package:fluvie_editor/src/commands/editor_clipboard.dart';
import 'package:fluvie_editor/src/commands/menu_templates.dart';
import 'package:fluvie_editor/src/document/deck_sections.dart';
import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/inspector/inspector_text_field.dart';
import 'package:fluvie_editor/src/widgets/editor_tip.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart' show SlidePreviewService;
import 'package:obers_ui/obers_ui.dart';

part 'slide_strip_masters.dart';
part 'slide_strip_sections.dart';
part 'slide_strip_tile.dart';

/// The left panel's slide strip: live thumbnails through the presenter's
/// preview cache, the current slide marked, with add, duplicate, delete,
/// drag-reorder, and named sections — all through the command layer.
///
/// While the deck has named sections the strip renders their headers
/// (collapse, inline rename, whole-section moves) and slide reordering
/// rides the tile menu; the free drag-reorder serves the sectionless strip.
final class SlideStrip extends StatefulWidget {
  /// Shows [document]'s slides; [current] is on stage.
  const SlideStrip({
    required this.document,
    required this.current,
    required this.service,
    required this.onSelect,
    required this.onCommand,
    this.clipboard,
    this.onEditMaster,
    this.extraMenuItems,
    super.key,
  });

  /// The deck being edited.
  final EditorDocument document;

  /// The slide on stage.
  final int current;

  /// The presenter's lazy, capped preview cache, bound to a document
  /// renderer by the host screen.
  final SlidePreviewService service;

  /// The clipboard the tile menus' Copy slide and Paste slide use, or null
  /// on a host without one (the items read disabled).
  final EditorClipboard? clipboard;

  /// Puts a slide on stage.
  final ValueChanged<int> onSelect;

  /// Receives the slide commands.
  final void Function(EditorCommand command) onCommand;

  /// Opens a master in master-edit mode — the masters row's pencil and the
  /// tile menu's Edit master land here. Null hides the edit affordances on
  /// a host without a master-edit surface.
  final void Function(String name)? onEditMaster;

  /// Extra tile-menu items the host appends (the slides app adds its
  /// template inserts here), built against the tile's command scope.
  final List<OiMenuItem> Function(CommandScope scope)? extraMenuItems;

  @override
  State<SlideStrip> createState() => _SlideStripState();
}

final class _SlideStripState extends State<SlideStrip> {
  // Eager: a lazy initializer would first run inside didUpdateWidget,
  // against the already-updated document, and never see the change.
  // The render digest covers everything render-affecting — scenes, the
  // theme, masters, size — so a token retint re-renders every thumbnail.
  late String _contentKey;

  @override
  void initState() {
    super.initState();
    _contentKey = widget.document.renderDigest;
  }

  @override
  void didUpdateWidget(SlideStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.document.renderDigest;
    // An edit anywhere invalidates the cache, so thumbnails re-render with
    // the change (the service has no per-slide eviction; re-rendering a
    // handful of thumbnails is cheaper than a stale preview).
    if (next != _contentKey) {
      _contentKey = next;
      // Deferred: notifying the tiles' listeners mid-build is illegal.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.service.invalidate();
      });
    }
  }

  Map<String, Object?> _blankScene() => {'duration': '3s', 'children': <Object?>[]};

  /// The registry scope for one tile: the tile's own index is the slide the
  /// menu commands act on, and the strip's select callback lets them follow
  /// their result.
  CommandScope _tileScope(int slide) => CommandScope(
    document: widget.document,
    slide: slide,
    dispatch: widget.onCommand,
    clipboard: widget.clipboard,
    showSlide: widget.onSelect,
    editMaster: widget.onEditMaster ?? _ignoreMaster,
  );

  static void _ignoreMaster(String name) {}

  /// One slide thumbnail row (both the flat and the sectioned list).
  Widget _tile(int slide) {
    final scope = _tileScope(slide);
    return _SlideTile(
      key: ValueKey('slide-$slide'),
      index: slide,
      current: slide == widget.current,
      service: widget.service,
      masterName: widget.document.sceneMasterName(slide),
      onTap: () => widget.onSelect(slide),
      menuItems: [
        ...slideStripMenuItems(scope),
        ...?widget.extraMenuItems?.call(scope),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final sections = deckSections(widget.document);
    final named = sections.any((section) => section.name != null);
    return Column(
      children: [
        if (widget.document.masterNames.isNotEmpty) _mastersRow(context),
        Expanded(
          child: named
              ? ListView(children: _sectionedRows(sections))
              : OiReorderable(
                  shrinkWrap: true,
                  onReorder: (from, to) => widget.onCommand(
                    ReorderSceneCommand(from: from, to: to > from ? to - 1 : to),
                  ),
                  children: [
                    for (var slide = 0; slide < widget.document.sceneCount; slide++) _tile(slide),
                  ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              EditorTip(
                message: 'Add slide',
                child: OiIconButton(
                  icon: OiIcons.plus,
                  semanticLabel: 'Add slide',
                  onTap: () => widget.onCommand(AddSceneCommand(scene: _blankScene())),
                ),
              ),
              EditorTip(
                message: 'Duplicate slide (fresh element ids)',
                child: OiIconButton(
                  icon: OiIcons.copy,
                  semanticLabel: 'Duplicate slide',
                  onTap: () => widget.onCommand(
                    AddSceneCommand(
                      scene: widget.document.duplicatedScene(widget.current),
                      at: widget.current + 1,
                    ),
                  ),
                ),
              ),
              EditorTip(
                message: 'Delete slide (a deck keeps at least one)',
                child: OiIconButton(
                  icon: OiIcons.trash,
                  semanticLabel: 'Delete slide',
                  onTap: widget.document.sceneCount > 1
                      ? () => widget.onCommand(RemoveSceneCommand(index: widget.current))
                      : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
