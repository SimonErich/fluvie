import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie_presenter/src/controller/presentation_controller.dart';
import 'package:fluvie_presenter/src/notes/notes_compiler.dart';
import 'package:fluvie_presenter/src/shell/ui_state.dart';
import 'package:obers_ui/obers_ui.dart' show OiBuildContextThemeExt, OiLabel;

/// The togglable bottom strip showing the current position's speaker notes:
/// the prose on the left, the highlight bullets down the right.
///
/// It follows navigation (step notes swap in as steps reveal) and hides
/// behind the N key or the `showNotes` flag. On mobile this panel is the
/// speaker surface — the pop-out window needs desktop or web.
final class NotesPanel extends ConsumerWidget {
  /// Creates the panel.
  const NotesPanel({this.height = 112, super.key});

  /// The strip's height in logical pixels.
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(notesVisibleProvider)) return const SizedBox.shrink();
    final notes = ref.watch(slideNotesProvider);
    final position = ref.watch(
      presentationControllerProvider.select((state) => state.position),
    );
    final current = notes[position.slide][position.step];
    final colors = context.colors;
    return ColoredBox(
      color: colors.surface,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: OiLabel.body(
                  current.text ?? 'No notes for this slide.',
                  color: current.text == null ? colors.textMuted : colors.text,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (current.highlights.isNotEmpty) ...[
                const SizedBox(width: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final highlight in current.highlights)
                      OiLabel.small('•  $highlight', color: colors.textSubtle),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
