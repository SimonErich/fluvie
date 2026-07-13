import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie_presenter/src/controller/presentation_controller.dart';
import 'package:fluvie_presenter/src/controller/presentation_position.dart';
import 'package:fluvie_presenter/src/shell/ui_state.dart';
import 'package:fluvie_presenter/src/stepping/slide_plan.dart';
import 'package:obers_ui/obers_ui.dart' show OiBuildContextThemeExt, OiLabel;

/// The minimal heads-up chrome: a slide counter bottom-right and a thin
/// progress line along the bottom edge, both hidden when the HUD toggle is
/// off. Progress measures the flat position order, so steps move it too.
final class StageHud extends ConsumerWidget {
  /// Creates the HUD.
  const StageHud({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(hudVisibleProvider)) return const SizedBox.shrink();
    final plans = ref.watch(slidePlansProvider);
    final position = ref.watch(
      presentationControllerProvider.select((state) => state.position),
    );
    final colors = context.colors;
    return IgnorePointer(
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
