import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/inspector/inspector_text_field.dart';
import 'package:fluvie_editor/src/panels/layers_drop.dart';
import 'package:fluvie_editor/src/selection/entered_group.dart';
import 'package:fluvie_editor/src/selection/selection_controller.dart';
import 'package:fluvie_editor/src/widgets/editor_tip.dart';
import 'package:obers_ui/obers_ui.dart';

part 'layers_panel_row.dart';

/// The current slide's element list, topmost first: click selects, the
/// name renames inline (editor-block metadata), lock (editor-block) and
/// hide (the spec `visible` flag) toggle, and drag reorders the z-index —
/// all through the command layer.
///
/// Groups render as collapsible subtrees; their children carry the same
/// controls, and tapping a child enters its group on the canvas. The whole
/// panel is one flat reorderable list, so a drag also crosses group
/// boundaries: dropping a row inside an expanded group's run moves it into
/// the group (transform rewritten group-relative — nothing moves on
/// screen), dropping a child at a top-level slot promotes it, and blocks on
/// both sides re-balance. Groups themselves never nest by drag.
final class LayersPanel extends ConsumerStatefulWidget {
  /// Lists slide [slide] of [document].
  const LayersPanel({
    required this.document,
    required this.slide,
    required this.onCommand,
    super.key,
  });

  /// The deck being edited.
  final EditorDocument document;

  /// The slide whose elements are listed.
  final int slide;

  /// Receives the layer commands.
  final void Function(EditorCommand command) onCommand;

  @override
  ConsumerState<LayersPanel> createState() => _LayersPanelState();
}

final class _LayersPanelState extends ConsumerState<LayersPanel> {
  String? _renaming;
  String? _lastTapId;
  int _lastTapMs = 0;
  final Set<String> _expanded = {};

  /// The canvas's manual double-tap: a second tap on the same row within
  /// 350 ms renames, without delaying single-tap selection. A single tap on
  /// a child also enters its group, so the canvas scope follows the panel.
  void _rowTap(String id, {String? parent}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (id == _lastTapId && now - _lastTapMs < 350) {
      setState(() => _renaming = id);
      return;
    }
    _lastTapId = id;
    _lastTapMs = now;
    if (parent == null) {
      ref.read(enteredGroupProvider.notifier).exit();
    } else {
      ref.read(enteredGroupProvider.notifier).enter(parent);
    }
    ref.read(selectionProvider.notifier).click(id);
  }

  String _nameOf(String id) {
    final name = widget.document.elementMeta(id)['name'];
    if (name is String && name.isNotEmpty) return name;
    return widget.document.elementJson(id)?['type'] as String? ?? id;
  }

  bool _locked(String id) => widget.document.elementMeta(id)['locked'] == true;

  bool _hidden(String id) => widget.document.elementJson(id)?['visible'] == false;

  bool _isGroup(String id) => widget.document.elementJson(id)?['type'] == 'Group';

  /// The panel as one flat list, topmost first: top-level rows, and — under
  /// each expanded group — its children (one level; the canvas enters one
  /// level too).
  List<LayerRowEntry> _rows() => [
    for (final id in widget.document.elementIdsInScene(widget.slide).reversed) ...[
      (id: id, parent: null, isGroup: _isGroup(id), expanded: _expanded.contains(id)),
      if (_isGroup(id) && _expanded.contains(id))
        for (final childId in widget.document.childIdsOfGroup(id).reversed)
          (id: childId, parent: id, isGroup: _isGroup(childId), expanded: false),
    ],
  ];

  /// One drop of the flat list: a reorder inside its own holding list, a
  /// move into the group whose run it landed in, or a promotion out — each
  /// one undo step through the command layer.
  void _onReorder(int from, int to) {
    switch (layersDropPlan(_rows(), from, to)) {
      case null:
        return;
      case LayersReorder(:final id, :final to):
        widget.onCommand(ReorderElementCommand(id: id, to: to));
      case LayersMoveIn(:final id, :final group, :final at):
        widget.onCommand(MoveIntoGroupCommand(id: id, groupId: group, at: at));
      case LayersMoveOut(:final id, :final group, :final at):
        widget.onCommand(MoveOutOfGroupCommand(id: id, groupId: group, at: at));
    }
  }

  Widget _row(String id, Set<String> selected, {String? parent}) => _LayerRow(
    key: ValueKey('layer-$id'),
    name: _nameOf(id),
    selected: selected.contains(id),
    locked: _locked(id),
    hidden: _hidden(id),
    renaming: _renaming == id,
    badge: widget.document.blockOf(id)?.kind.label,
    expanded: _isGroup(id) ? _expanded.contains(id) : null,
    onToggleExpand: !_isGroup(id)
        ? null
        : () => setState(() => _expanded.contains(id) ? _expanded.remove(id) : _expanded.add(id)),
    onTap: () => _rowTap(id, parent: parent),
    onRenamed: (name) {
      setState(() => _renaming = null);
      widget.onCommand(SetElementMetaCommand(id: id, meta: {'name': name}));
    },
    onLock: () => widget.onCommand(SetElementMetaCommand(id: id, meta: {'locked': !_locked(id)})),
    onHide: () => widget.onCommand(SetElementsVisibleCommand(ids: [id], visible: _hidden(id))),
  );

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectionProvider);
    // Topmost first, one flat reorderable: dragging across a group's run
    // moves rows into and out of it (see [layersDropPlan]).
    return OiReorderable(
      shrinkWrap: true,
      onReorder: _onReorder,
      children: [
        for (final entry in _rows())
          if (entry.parent == null)
            _row(entry.id, selected)
          else
            Padding(
              key: ValueKey('layer-slot-${entry.id}'),
              padding: const EdgeInsets.only(left: 16),
              child: _row(entry.id, selected, parent: entry.parent),
            ),
      ],
    );
  }
}
