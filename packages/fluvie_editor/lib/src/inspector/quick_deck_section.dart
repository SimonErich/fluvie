import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart' show encodeColor;
import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/inspector/slide_duration_section.dart';
import 'package:fluvie_editor/src/inspector/transform_section.dart';
import 'package:fluvie_editor/src/theme/token_color_scope.dart';
import 'package:fluvie_editor/src/widgets/color_field.dart';
import 'package:obers_ui/obers_ui.dart';

/// Canvas size, scene length and the background's primary colour: six rows.
final class QuickDeckSection extends StatelessWidget {
  /// Edits the scene through ordinary undoable commands.
  const QuickDeckSection({
    required this.document,
    required this.slide,
    required this.onCommand,
    required this.colors,
    super.key,
  });

  /// The immutable open document.
  final EditorDocument document;

  /// The active scene index.
  final int slide;

  /// Dispatches one user edit.
  final ValueChanged<EditorCommand> onCommand;

  /// Resolves document and theme colours.
  final TokenColorScope colors;
  @override
  Widget build(BuildContext context) {
    final raw = document.sceneJson(slide)['background'];
    final background = raw is Map<String, Object?> ? raw : <String, Object?>{};
    final kind = background['kind'] as String? ?? 'none';
    final stops = background['colors'];
    final gradient = (kind == 'gradient' || kind == 'radial') && stops is List && stops.isNotEmpty;
    final editable = const {'none', 'color', 'gradient', 'radial'}.contains(kind);
    final color = gradient ? stops.first : background['color'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const OiLabel.small('Essentials'),
        SlideSizeSection(
          width: document.spec.size.width.toDouble(),
          height: document.spec.size.height.toDouble(),
          onChanged: (w, h) => onCommand(
            UpdateVideoCommand(
              patch: {
                'size': {'width': w.round(), 'height': h.round()},
              },
            ),
          ),
        ),
        SlideDurationSection(document: document, slide: slide, onCommand: onCommand),
        OiPropertyGrid(
          properties: [
            OiPropertyRow(label: 'Background', editor: OiLabel.body(kind)),
            OiPropertyRow(
              label: 'Color',
              editor: editable
                  ? ColorField(
                      label: 'Background color',
                      color: colors.resolve(color, const Color(0xFF101018)),
                      onChanged: (next) {
                        onCommand(
                          UpdateSceneCommand(
                            index: slide,
                            patch: {
                              'background': gradient
                                  ? {
                                      ...background,
                                      'colors': [encodeColor(next), ...stops.skip(1)],
                                    }
                                  : {'kind': 'color', 'color': encodeColor(next)},
                            },
                            mergeGroup: 'quick-background',
                          ),
                        );
                      },
                    )
                  : const OiLabel.small('Open Edit to adjust this background.'),
            ),
          ],
        ),
      ],
    );
  }
}
