import 'package:flutter/material.dart';
import 'package:fluvie_example/theme/fluvie_gradients.dart';
import 'package:fluvie_example/theme/fluvie_shadows.dart';

/// The landing page's signature CTA: a button filled with the brand gradient and
/// a soft glow that lifts and brightens on hover. Dims when [onPressed] is null.
///
/// Used for the primary actions (Render, Generate). Exposes [onPressed] so tests
/// can assert the enabled/disabled state.
final class GradientButton extends StatefulWidget {
  /// Creates a gradient button with a [label], optional leading [icon], and a
  /// tap handler ([onPressed]); a null handler disables and dims it.
  const GradientButton({required this.label, required this.onPressed, this.icon, super.key});

  /// The button label.
  final String label;

  /// An optional leading widget (an icon or a spinner).
  final Widget? icon;

  /// The tap handler; null disables and dims the button.
  final VoidCallback? onPressed;

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final lifted = enabled && _hovered;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, lifted ? -2 : 0, 0),
          decoration: BoxDecoration(
            gradient: FluvieGradients.primary,
            borderRadius: BorderRadius.circular(FluvieRadii.button),
            boxShadow: enabled
                ? (lifted ? FluvieElevations.ctaGlowStrong : FluvieElevations.ctaGlow)
                : null,
          ),
          // A subtle white sheen brightens the gradient on hover.
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FluvieRadii.button),
            color: lifted ? const Color(0x1AFFFFFF) : const Color(0x00FFFFFF),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: widget.onPressed,
              borderRadius: BorderRadius.circular(FluvieRadii.button),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      IconTheme.merge(
                        data: const IconThemeData(color: Colors.white, size: 18),
                        child: widget.icon!,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      widget.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
