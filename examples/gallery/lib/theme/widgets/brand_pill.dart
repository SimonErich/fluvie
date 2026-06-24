import 'package:flutter/widgets.dart';
import 'package:fluvie_example/theme/fluvie_colors.dart';
import 'package:fluvie_example/theme/fluvie_shadows.dart';

/// A small rounded pill/badge matching the landing page's dark glass pills: a
/// translucent fill, a hairline border, and an optional leading status [dot].
final class BrandPill extends StatelessWidget {
  /// Creates a pill showing [label], optionally preceded by a colored [dot].
  const BrandPill({required this.label, this.dot, this.color, super.key});

  /// The pill text.
  final String label;

  /// An optional leading status-dot color.
  final Color? dot;

  /// The text color; defaults to [FluvieColors.pillText].
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x12FFFFFF),
        borderRadius: BorderRadius.circular(FluvieRadii.pill),
        border: Border.all(color: const Color(0x29FFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot != null) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: TextStyle(
              color: color ?? FluvieColors.pillText,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
