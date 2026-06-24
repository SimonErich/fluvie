import 'package:flutter/material.dart';

/// A small status banner: an icon beside content on a tinted rounded surface.
///
/// Shared by the example apps for their render success and error states, so the
/// status UI looks the same across the set.
class KittenBanner extends StatelessWidget {
  /// Creates a banner tinted with [color], leading with [icon] beside [child].
  const KittenBanner({
    required this.color,
    required this.icon,
    required this.child,
    super.key,
  });

  /// The accent color of the icon and the surface tint.
  final Color color;

  /// The leading status icon.
  final IconData icon;

  /// The banner content (usually a `Text` or a small `Column`).
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}
