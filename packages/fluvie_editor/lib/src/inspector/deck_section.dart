import 'package:flutter/widgets.dart';
import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/inspector/auto_animate_section.dart';
import 'package:fluvie_editor/src/inspector/background_editor.dart';
import 'package:fluvie_editor/src/inspector/slide_duration_section.dart';
import 'package:fluvie_editor/src/inspector/transform_section.dart';
import 'package:fluvie_editor/src/theme/token_color_scope.dart';
import 'package:obers_ui/obers_ui.dart';

/// The nothing-selected inspector: slide size, background, and (past the
/// first slide) the auto-animate toggle — every control dispatches a
/// command, so every change is undoable.
final class DeckSection extends StatelessWidget {
  /// Inspects slide [slide] of [document]; commands land in [onCommand],
  /// and [colors] carries the theme palette into the background editor.
  const DeckSection({
    required this.document,
    required this.slide,
    required this.onCommand,
    required this.colors,
    this.onNote,
    super.key,
  });

  /// The deck being edited.
  final EditorDocument document;

  /// The slide on stage.
  final int slide;

  /// Receives every dispatched command.
  final void Function(EditorCommand command) onCommand;

  /// The theme palette and session recents for the color fields.
  final TokenColorScope colors;

  /// Hears a refusal or a clamp from a retime, or null on a surface with
  /// nowhere to show one.
  final ValueChanged<String>? onNote;

  @override
  Widget build(BuildContext context) {
    final size = document.spec.size;
    final scene = document.sceneJson(slide);
    final background = scene['background'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _header(context, 'Slide'),
        SlideSizeSection(
          width: size.width.toDouble(),
          height: size.height.toDouble(),
          onChanged: (width, height) => onCommand(
            UpdateVideoCommand(
              patch: {
                'size': {'width': width.round(), 'height': height.round()},
              },
            ),
          ),
        ),
        _header(context, 'Length'),
        SlideDurationSection(
          document: document,
          slide: slide,
          onCommand: onCommand,
          onNote: onNote,
        ),
        _header(context, 'Background'),
        BackgroundEditor(
          background: background is Map<String, Object?> ? background : null,
          colors: colors,
          onPatch: (next, {mergeGroup}) => onCommand(
            UpdateSceneCommand(index: slide, patch: {'background': next}, mergeGroup: mergeGroup),
          ),
        ),
        if (slide > 0) ...[
          _header(context, 'Auto-animate'),
          AutoAnimateSection(document: document, slide: slide, onCommand: onCommand),
        ],
      ],
    );
  }

  Widget _header(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4),
    child: OiLabel.small(text, color: context.colors.textSubtle),
  );
}
