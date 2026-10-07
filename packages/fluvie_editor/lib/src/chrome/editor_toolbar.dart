import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie_editor/src/shell/editor_workspace.dart';
import 'package:fluvie_editor/src/snapping/snap_preferences.dart';
import 'package:fluvie_editor/src/tools/tool_controller.dart';
import 'package:fluvie_editor/src/widgets/editor_tip.dart';
import 'package:obers_ui/obers_ui.dart';

/// The vertical tool group beside the canvas: select, hand, text, the four
/// shapes, media — and, when the host offers one, the asset panel.
final class EditorToolbar extends ConsumerWidget {
  /// Creates the toolbar; [onAssets] (when non-null) adds the asset-panel
  /// button.
  const EditorToolbar({this.onAssets, super.key});

  /// Opens the asset reuse panel.
  final VoidCallback? onAssets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(toolProvider);
    final controller = ref.read(toolProvider.notifier);
    Widget button({
      required IconData icon,
      required String label,
      required bool active,
      required VoidCallback onTap,
    }) => EditorTip(
      message: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: active ? context.colors.accent.base.withValues(alpha: 0.18) : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: OiIconButton(icon: icon, semanticLabel: label, onTap: onTap),
      ),
    );

    bool shapeActive(ShapeVariant variant) =>
        state.tool == EditorTool.shape && state.shape == variant;

    // Quick shows the three tools that are enough to make a video; the rest
    // are still there the moment the author switches, and nothing about the
    // document changes either way.
    final full = WorkspaceScope.disclosureOf(context) == DisclosureLevel.full;

    return ColoredBox(
      color: context.colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            button(
              icon: OiIcons.mousePointer,
              label: 'Select tool (V)',
              active: state.tool == EditorTool.select,
              onTap: controller.reset,
            ),
            button(
              icon: OiIcons.move,
              label: 'Hand tool (H)',
              active: state.tool == EditorTool.hand,
              onTap: () => controller.activate(EditorTool.hand),
            ),
            button(
              icon: OiIcons.typeIcon,
              label: 'Text tool (T)',
              active: state.tool == EditorTool.text,
              onTap: () => controller.activate(EditorTool.text),
            ),
            if (full) ...[
              button(
                icon: OiIcons.square,
                label: 'Rectangle tool (R)',
                active: shapeActive(ShapeVariant.rectangle),
                onTap: () => controller.pickShape(ShapeVariant.rectangle),
              ),
              button(
                icon: OiIcons.circle,
                label: 'Ellipse tool (O)',
                active: shapeActive(ShapeVariant.ellipse),
                onTap: () => controller.pickShape(ShapeVariant.ellipse),
              ),
              button(
                icon: OiIcons.minus,
                label: 'Line tool (L)',
                active: shapeActive(ShapeVariant.line),
                onTap: () => controller.pickShape(ShapeVariant.line),
              ),
              button(
                icon: OiIcons.arrowUpRight,
                label: 'Arrow tool (A)',
                active: shapeActive(ShapeVariant.arrow),
                onTap: () => controller.pickShape(ShapeVariant.arrow),
              ),
            ],
            button(
              icon: OiIcons.image,
              label: 'Media tool (M)',
              active: state.tool == EditorTool.media,
              onTap: () => controller.activate(EditorTool.media),
            ),
            const SizedBox(height: 8),
            if (full)
              button(
                icon: OiIcons.ruler,
                label: 'Rulers and guides',
                active: ref.watch(snapPreferencesProvider).rulers,
                onTap: ref.read(snapPreferencesProvider.notifier).toggleRulers,
              ),
            if (onAssets != null) ...[
              const SizedBox(height: 8),
              EditorTip(
                message: 'Deck assets: reuse media already in the deck',
                child: OiIconButton(
                  icon: OiIcons.folderOpen,
                  semanticLabel: 'Deck assets',
                  onTap: onAssets,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
