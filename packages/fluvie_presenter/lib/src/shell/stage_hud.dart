import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie_presenter/src/controller/presentation_controller.dart';
import 'package:fluvie_presenter/src/controller/presentation_position.dart';
import 'package:fluvie_presenter/src/shell/presentation_shortcuts.dart';
import 'package:fluvie_presenter/src/shell/ui_state.dart';
import 'package:fluvie_presenter/src/stepping/slide_plan.dart';
import 'package:obers_ui/obers_ui.dart'
    show OiBuildContextThemeExt, OiButtonSize, OiIconButton, OiIcons, OiLabel, OiTooltip;

/// The minimal heads-up chrome: a slide counter bottom-right, a thin
/// progress line along the bottom edge, and a small control strip top-right
/// so the chrome is clickable too — all hidden when the HUD toggle is off.
/// Progress measures the flat position order, so steps move it too.
final class StageHud extends ConsumerWidget {
  /// Creates the HUD wired to the shell's [handlers].
  const StageHud({required this.handlers, super.key});

  /// The same intentions the keyboard fires; the strip's buttons reuse them.
  final PresenterHandlers handlers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(hudVisibleProvider)) return const SizedBox.shrink();
    final plans = ref.watch(slidePlansProvider);
    final position = ref.watch(
      presentationControllerProvider.select((state) => state.position),
    );
    final colors = context.colors;
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16, bottom: 12),
                  child: OiLabel.small(
                    '${position.slide + 1} / ${plans.length}',
                    color: colors.textSubtle,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomLeft,
                child: FractionallySizedBox(
                  alignment: Alignment.bottomLeft,
                  widthFactor: _progress(plans, position),
                  child: SizedBox(height: 3, child: ColoredBox(color: colors.accent.base)),
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.topRight,
          child: _ControlStrip(handlers: handlers),
        ),
      ],
    );
  }

  /// Where the position sits in the flat order, 0 at the first position and
  /// 1 at the last.
  double _progress(List<SlidePlan> plans, PresentationPosition position) {
    var flat = 0;
    var total = 0;
    for (var s = 0; s < plans.length; s++) {
      if (s < position.slide) flat += plans[s].stepCount;
      total += plans[s].stepCount;
    }
    flat += position.step;
    return total <= 1 ? 1 : flat / (total - 1);
  }
}

/// The clickable half of the HUD: one small ghost button per piece of
/// chrome, reusing the exact intentions the keyboard fires.
final class _ControlStrip extends StatelessWidget {
  const _ControlStrip({required this.handlers});

  final PresenterHandlers handlers;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, right: 8),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _HudButton(
          icon: OiIcons.panelLeft,
          label: 'Slide list',
          shortcut: 'T',
          onTap: handlers.onToggleSidebar,
        ),
        _HudButton(
          icon: OiIcons.notepadText,
          label: 'Speaker notes',
          shortcut: 'N',
          onTap: handlers.onToggleNotes,
        ),
        _HudButton(
          icon: OiIcons.layoutGrid,
          label: 'Overview',
          shortcut: 'O',
          onTap: handlers.onOverview,
        ),
        _HudButton(
          icon: OiIcons.presentation,
          label: 'Speaker window',
          shortcut: 'S',
          onTap: handlers.onSpeakerWindow,
        ),
        _HudButton(
          icon: OiIcons.maximize,
          label: 'Fullscreen',
          shortcut: 'F',
          onTap: handlers.onToggleFullscreen,
        ),
      ],
    ),
  );
}

/// One strip button: a ghost icon with its shortcut in the tooltip. The
/// tooltip needs an `Overlay` (an `OiApp` provides one); without it the
/// button still works, just without the hover hint.
final class _HudButton extends StatelessWidget {
  const _HudButton({
    required this.icon,
    required this.label,
    required this.shortcut,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String shortcut;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OiTooltip(
    label: label,
    message: '$label ($shortcut)',
    child: OiIconButton(
      icon: icon,
      semanticLabel: label,
      size: OiButtonSize.small,
      onTap: onTap,
    ),
  );
}
