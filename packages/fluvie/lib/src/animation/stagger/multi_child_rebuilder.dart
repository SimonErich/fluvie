import 'package:flutter/widgets.dart';

/// The direct children of a supported multi-child stagger target, in
/// declaration order — or `null` for anything else.
///
/// Supported containers are direct [Flex] descendants (`Row`/`Column` *are*
/// [Flex]), [Wrap], and [Stack]; `null` is the single-child sentinel: the
/// caller renders the target unstaggered instead of guessing at an unknown
/// container's semantics. A [KeyedSubtree] is transparent — `MotionTarget`
/// wraps its child in one under a composition registrar (identity across
/// the collect passes), and stagger must keep seeing the container inside.
List<Widget>? wrappableChildrenOf(Widget container) => switch (container) {
  KeyedSubtree(:final child) => wrappableChildrenOf(child),
  Flex(:final children) || Wrap(:final children) || Stack(:final children) => children,
  _ => null,
};

/// Rebuilds [container] with every direct child passed through [wrap],
/// or returns `null` when [container] is not a supported
/// multi-child target — the caller's signal to take the single-child path.
///
/// The rebuilt container copies the original's key and every layout property
/// ([Flex] direction/alignment/spacing, the full [Wrap] set, [Stack]
/// alignment/fit/clip), so geometry is untouched; only the children change.
/// [ParentDataWidget]s ([Positioned], [Flexible]/[Expanded]) are preserved by
/// wrapping *inside* them — their parent-data must stay the container's
/// direct child or the framework rejects the tree. A [KeyedSubtree] shell is
/// rebuilt around the rebuilt container, key preserved (see
/// [wrappableChildrenOf]).
Widget? rebuildWithWrappedChildren(
  Widget container,
  Widget Function(int index, Widget child) wrap,
) => switch (container) {
  final KeyedSubtree keyed => switch (rebuildWithWrappedChildren(keyed.child, wrap)) {
    null => null,
    final rebuilt => KeyedSubtree(key: keyed.key, child: rebuilt),
  },
  final Flex flex => _rebuildFlex(flex, wrap),
  final Wrap wrapBox => _rebuildWrap(wrapBox, wrap),
  final Stack stack => _rebuildStack(stack, wrap),
  _ => null,
};

/// One [Flex] with [flex]'s full property set; covers `Row` and `Column`.
Widget _rebuildFlex(Flex flex, Widget Function(int, Widget) wrap) => Flex(
  key: flex.key,
  direction: flex.direction,
  mainAxisAlignment: flex.mainAxisAlignment,
  mainAxisSize: flex.mainAxisSize,
  crossAxisAlignment: flex.crossAxisAlignment,
  textDirection: flex.textDirection,
  verticalDirection: flex.verticalDirection,
  textBaseline: flex.textBaseline,
  clipBehavior: flex.clipBehavior,
  spacing: flex.spacing,
  children: _wrapAll(flex.children, wrap),
);

/// One [Wrap] with [original]'s full property set.
Widget _rebuildWrap(Wrap original, Widget Function(int, Widget) wrap) => Wrap(
  key: original.key,
  direction: original.direction,
  alignment: original.alignment,
  spacing: original.spacing,
  runAlignment: original.runAlignment,
  runSpacing: original.runSpacing,
  crossAxisAlignment: original.crossAxisAlignment,
  textDirection: original.textDirection,
  verticalDirection: original.verticalDirection,
  clipBehavior: original.clipBehavior,
  children: _wrapAll(original.children, wrap),
);

/// One [Stack] with [stack]'s full property set.
Widget _rebuildStack(Stack stack, Widget Function(int, Widget) wrap) => Stack(
  key: stack.key,
  alignment: stack.alignment,
  textDirection: stack.textDirection,
  fit: stack.fit,
  clipBehavior: stack.clipBehavior,
  children: _wrapAll(stack.children, wrap),
);

List<Widget> _wrapAll(List<Widget> children, Widget Function(int, Widget) wrap) => [
  for (var i = 0; i < children.length; i++) _wrapInsideParentData(i, children[i], wrap),
];

/// Wraps one child, rebuilding a known [ParentDataWidget] shell around the
/// wrapped grandchild ([Expanded] before [Flexible]: it *is* a Flexible).
Widget _wrapInsideParentData(int index, Widget child, Widget Function(int, Widget) wrap) =>
    switch (child) {
      final Expanded expanded => Expanded(
        key: expanded.key,
        flex: expanded.flex,
        child: wrap(index, expanded.child),
      ),
      final Flexible flexible => Flexible(
        key: flexible.key,
        flex: flexible.flex,
        fit: flexible.fit,
        child: wrap(index, flexible.child),
      ),
      final Positioned positioned => Positioned(
        key: positioned.key,
        left: positioned.left,
        top: positioned.top,
        right: positioned.right,
        bottom: positioned.bottom,
        width: positioned.width,
        height: positioned.height,
        child: wrap(index, positioned.child),
      ),
      _ => wrap(index, child),
    };
