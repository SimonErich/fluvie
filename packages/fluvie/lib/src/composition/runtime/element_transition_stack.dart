import 'package:flutter/widgets.dart';
import 'package:fluvie/src/composition/runtime/collectible_children.dart';
import 'package:fluvie/src/composition/transition/transition_strategy.dart';
import 'package:fluvie/src/rendering/runtime/frame_clamp.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/rendering/runtime/preparation_scope.dart';
import 'package:fluvie/src/serialization/element_transition_spec.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';

/// A holding list with clip transitions composed in the clips' existing paint
/// slots. Unrelated siblings retain their position in the stack. Child state
/// survives strategy-wrapper changes through stable keys.
final class ElementTransitionStack extends StatefulWidget implements CollectibleChildren {
  /// Mounts the declared children under their resolved clip transition layout.
  const ElementTransitionStack({
    required this.children,
    required this.ids,
    required this.blends,
    super.key,
  });

  /// Children in unchanged declaration order, with effective show windows.
  final List<Widget> children;

  /// Stable identity at each child position, null for anonymous children.
  final List<String?> ids;

  /// Blends resolved on this holding list's parent clock.
  final List<ElementTransitionWindow> blends;
  @override
  Iterable<Widget> get collectibleChildren => children;
  @override
  State<ElementTransitionStack> createState() => _ElementTransitionStackState();
}

final class _ElementTransitionStackState extends State<ElementTransitionStack> {
  final _keys = <Object, GlobalKey>{};
  @override
  Widget build(BuildContext context) {
    final scope = TimeScopeProvider.of(context);
    final absolute = FrameProvider.of(context).frame;
    final frame = absolute - scope.startFrame;
    final children = [
      for (var i = 0; i < widget.children.length; i++)
        KeyedSubtree(
              key: _keys.putIfAbsent(widget.ids[i] ?? i, GlobalKey.new),
              child: widget.children[i],
            )
            as Widget,
    ];
    if (PreparationScope.isPreparing(context)) {
      return Stack(alignment: Alignment.center, children: children);
    }
    for (final blend in widget.blends) {
      if (!blend.contains(frame)) continue;
      final a = widget.ids.indexOf(blend.outgoing);
      final b = widget.ids.indexOf(blend.incoming);
      if (a < 0 || b < 0) continue;
      final held = blend.holdFrame;
      final outgoing = held == null
          ? children[a]
          : FrameClamp(holdFrame: scope.startFrame + held, child: children[a]);
      final pair = strategyFor(blend.transition.customKind ?? blend.transition.kind).compose(
        outgoing: outgoing,
        incoming: children[b],
        easedProgress: blend.transition.ease.transform(blend.progressAt(frame)),
        spec: blend.transition,
      );
      // A strategy may return a more elaborate list; keep it in the upper slot
      // while ordinary two-widget strategies retain the two existing slots.
      if (pair.length == 2) {
        children[a < b ? a : b] = pair[0];
        children[a < b ? b : a] = pair[1];
      } else {
        children[a < b ? a : b] = const SizedBox.shrink();
        children[a < b ? b : a] = Stack(alignment: Alignment.center, children: pair);
      }
    }
    return Stack(alignment: Alignment.center, children: children);
  }
}
