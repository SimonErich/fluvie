import 'package:flutter/widgets.dart';
import 'package:fluvie_editor/src/effects/effect_catalog.dart';
import 'package:fluvie_editor/src/effects/effect_drag_data.dart';
import 'package:fluvie_editor/src/widgets/editor_tip.dart';
import 'package:obers_ui/obers_ui.dart';

/// The add-an-effect browser: a searchable select for the quick add, and
/// the grouped chips underneath — each one tappable to add and draggable
/// onto the canvas or a timeline bar, because both drops land the same
/// command an add does.
final class EffectBrowser extends StatelessWidget {
  /// Calls [onAdd] with the chosen effect's document JSON.
  const EffectBrowser({required this.onAdd, super.key});

  /// Receives the effect to append, in document form.
  final void Function(Map<String, Object?> effect) onAdd;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<EffectCatalogEntry>>{};
    for (final entry in effectCatalog) {
      groups.putIfAbsent(entry.group, () => []).add(entry);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        OiSelect<String>(
          key: const ValueKey('effect-add'),
          options: [
            for (final entry in effectCatalog)
              OiSelectOption(value: entry.kind.name, label: entry.kind.name),
          ],
          placeholder: 'Add effect',
          searchable: true,
          onChanged: (kind) {
            if (kind == null) return;
            onAdd(effectCatalog.firstWhere((entry) => entry.kind.name == kind).json());
          },
        ),
        for (final group in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: OiLabel.small(group.key, color: context.colors.textSubtle),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final entry in group.value) _chip(context, entry)],
          ),
        ],
      ],
    );
  }

  Widget _chip(BuildContext context, EffectCatalogEntry entry) => Draggable<EffectDragData>(
    data: EffectDragData(entry.json()),
    // Pointer-anchored, so a drop target reading the drag offset reads the
    // pointer itself and the effect lands exactly where the author aimed.
    dragAnchorStrategy: pointerDragAnchorStrategy,
    feedback: OiBadge.filled(label: entry.kind.name),
    child: EditorTip(
      message: entry.blurb,
      child: OiButton.secondary(
        key: ValueKey('effect-chip-${entry.kind.name}'),
        label: entry.kind.name,
        size: OiButtonSize.small,
        onTap: () => onAdd(entry.json()),
      ),
    ),
  );
}
