import 'package:flutter/widgets.dart';
import 'package:fluvie_example/theme/fluvie_colors.dart';
import 'package:fluvie_example/theme/fluvie_text_theme.dart';

/// A small uppercase section label in JetBrains Mono with the brand accent,
/// matching the landing page's section labels (for example "LESSONS").
final class SectionLabel extends StatelessWidget {
  /// Creates a label showing [text] (rendered uppercase).
  const SectionLabel(this.text, {this.color, super.key});

  /// The label text (uppercased on render).
  final String text;

  /// The label color; defaults to the brand accent.
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: fluvieMono(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.72,
      color: color ?? FluvieColors.acc,
    ),
  );
}
