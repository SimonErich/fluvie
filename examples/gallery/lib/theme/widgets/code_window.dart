import 'package:flutter/material.dart';
import 'package:fluvie_example/theme/fluvie_colors.dart';
import 'package:fluvie_example/theme/fluvie_shadows.dart';
import 'package:fluvie_example/theme/fluvie_text_theme.dart';

/// A dark "code window" matching the landing page's code cards: a rounded dark
/// card with a macOS-style title bar (three traffic-light dots, a monospace
/// filename, and a language tag) above [child].
final class CodeWindow extends StatelessWidget {
  /// Creates a code window titled [filename] (tagged [languageLabel]) around
  /// [child].
  const CodeWindow({
    required this.child,
    this.filename = 'lesson.dart',
    this.languageLabel = 'Dart',
    super.key,
  });

  /// The content: an editor or a code/JSON view.
  final Widget child;

  /// The filename shown in the title bar.
  final String filename;

  /// The language tag shown at the right of the title bar.
  final String languageLabel;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: FluvieColors.dark,
        borderRadius: BorderRadius.circular(FluvieRadii.card),
        border: Border.all(color: FluvieColors.dline),
        boxShadow: FluvieElevations.codeWindow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(FluvieRadii.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TitleBar(filename: filename, languageLabel: languageLabel),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({required this.filename, required this.languageLabel});

  final String filename;
  final String languageLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      decoration: const BoxDecoration(
        color: FluvieColors.dpanel,
        border: Border(bottom: BorderSide(color: Color(0x12FFFFFF))),
      ),
      child: Row(
        children: [
          const _Dot(FluvieColors.dotRed),
          const SizedBox(width: 6),
          const _Dot(FluvieColors.dotYellow),
          const SizedBox(width: 6),
          const _Dot(FluvieColors.dotGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              filename,
              overflow: TextOverflow.ellipsis,
              style: fluvieMono(fontSize: 11, color: FluvieColors.dmut),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: FluvieColors.acc2.withValues(alpha: 0.3)),
            ),
            child: Text(
              languageLabel,
              style: fluvieMono(fontSize: 10, color: FluvieColors.acc2),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 9,
    height: 9,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
