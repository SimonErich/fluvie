import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie/fluvie.dart' show decodeColor, decodeTime, encodeColor, namedEases;
import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/inspector/inspector_text_field.dart';
import 'package:fluvie_editor/src/theme/builtin_themes.dart';
import 'package:fluvie_editor/src/theme/recent_colors.dart';
import 'package:fluvie_editor/src/widgets/color_field.dart';
import 'package:fluvie_editor/src/widgets/editor_tip.dart';
import 'package:fluvie_editor/src/widgets/math_number_input.dart';
import 'package:obers_ui/obers_ui.dart';

part 'theme_panel_palette.dart';
part 'theme_panel_scales.dart';

/// The Theme panel: the deck's design tokens, live-editable — palette
/// colors (add, rename, remove), the type scale, spacing steps, and motion
/// defaults — plus the builtin themes to start from. Every edit is one
/// undoable [SetThemeCommand]; renames ride [RenameThemeTokenCommand] so
/// bound references follow.
final class ThemePanel extends ConsumerWidget {
  /// Edits [document]'s theme; commands land in [onCommand].
  const ThemePanel({required this.document, required this.onCommand, super.key});

  /// The deck being edited.
  final EditorDocument document;

  /// Receives every dispatched command.
  final void Function(EditorCommand command) onCommand;

  Map<String, Object?> get _theme => document.themeJson ?? const {};

  Map<String, Object?> _tokenMap(String map) {
    final entries = _theme[map];
    return entries is Map<String, Object?> ? entries : const {};
  }

  /// Every token name across the palette and type scale — kept collision
  /// free, because a rename rewrites references by name alone.
  Set<String> get _takenNames => {..._tokenMap('palette').keys, ..._tokenMap('typeScale').keys};

  void _set(Map<String, Object?> theme, {String? mergeGroup, String verb = 'Edit'}) =>
      onCommand(SetThemeCommand(theme: theme, mergeGroup: mergeGroup, verb: verb));

  /// The theme with `[map][key]` set to [value] (null removes the entry;
  /// an emptied map drops off whole, keeping the JSON canonical).
  Map<String, Object?> _with(String map, String key, Object? value) {
    final entries = {..._tokenMap(map)};
    if (value == null) {
      entries.remove(key);
    } else {
      entries[key] = value;
    }
    final theme = {..._theme, map: entries};
    if (entries.isEmpty) theme.remove(map);
    return theme;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recents = ref.watch(recentColorsProvider);
    final onPicked = ref.read(recentColorsProvider.notifier).record;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(context, 'Start from'),
            _startFrom(context),
            _header(context, 'Palette'),
            ..._paletteSection(context, recents, onPicked),
            if (_tokenMap('typeScale').isNotEmpty) ...[
              _header(context, 'Type scale'),
              ..._typeScaleSection(context),
            ],
            if (_tokenMap('spacing').isNotEmpty) ...[
              _header(context, 'Spacing'),
              _spacingSection(context),
            ],
            _header(context, 'Motion'),
            _motionSection(context),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4),
    child: OiLabel.small(text, color: context.colors.textSubtle),
  );

  Widget _startFrom(BuildContext context) => Wrap(
    spacing: 4,
    runSpacing: 4,
    children: [
      for (final entry in builtinThemes.entries)
        // No semantics label: the chip's own text is the label (a wrapper
        // label would swallow it, the OiTooltip lesson).
        Semantics(
          container: true,
          button: true,
          child: GestureDetector(
            onTap: () => _set(entry.value, verb: 'Apply'),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.colors.surfaceSubtle,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: context.colors.borderSubtle),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: OiLabel.small(entry.key, color: context.colors.text),
              ),
            ),
          ),
        ),
    ],
  );
}
