/// @docImport 'package:fluvie/src/timing/window_scope.dart';
library;

import 'package:flutter/widgets.dart';
import 'package:fluvie/src/animation/motion_target.dart';
import 'package:fluvie/src/composition/clip_transition.dart';
import 'package:fluvie/src/composition/runtime/collectible_children.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/timing/placement/window_resolver.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

/// Walks each scene's `Background` and declared children, calling [visit] for
/// every widget found in pre-order build sequence — the one tree walk every
/// collector shares (media, snapshot, and generative).
///
/// Pure and structural: it never mounts or builds anything, so it runs before
/// the frame loop. Callers filter the visited widgets to the marker interface
/// they care about (`MediaCarrier`, `GenerativeCarrier`, `Snapshot`).
void walkSceneTree(
  List<Scene> scenes,
  void Function(Widget widget) visit, {
  List<Widget> overlays = const [],
}) {
  for (final scene in scenes) {
    final background = scene.background;
    if (background != null) walkWidgetTree(background, visit);
    for (final child in scene.children) {
      walkWidgetTree(child, visit);
    }
  }
  // The overlays belong to no scene, but they render, so every pre-pass that
  // resolves media before the frame loop has to see them too.
  for (final overlay in overlays) {
    walkWidgetTree(overlay, visit);
  }
}

/// Walks [widget] and its declared children, threading the [TimeScopeData] each
/// one renders under — the static mirror of how [WindowScope] nests at runtime.
///
/// A [MotionTarget] publishes `elementScopeFor(window, nearest)` over its
/// child, so an inner window measures against the enclosing one rather than
/// against the scene, and a window-less target passes its scope straight
/// through. Threading the same rule here is what lets a pre-pass compute the
/// exact scope a painter will read from `TimeScopeProvider`, without mounting
/// anything.
///
/// [visit] sees each widget with the scope it *builds* under, so a
/// [MotionTarget] itself is visited with the enclosing scope and its subtree
/// with the windowed one.
void walkScopedTree(
  Widget widget,
  TimeScopeData scope,
  void Function(Widget widget, TimeScopeData scope) visit,
) {
  visit(widget, scope);
  final below = widget is MotionTarget ? elementScopeFor(widget.window, scope) : scope;
  final children = widget is ClipTransitionGroup
      ? widget.resolve(scope).children
      : declaredChildren(widget);
  for (final child in children) {
    walkScopedTree(child, below, visit);
  }
}

/// Visits [widget] then recurses into its declared children in build order — the
/// multi-child layouts (`Column`/`Row`/`Stack`/`Wrap` via
/// [MultiChildRenderObjectWidget]), the single-child wrappers
/// (`Center`/`Align`/`Padding`/`SizedBox` via [SingleChildRenderObjectWidget]),
/// a [MotionTarget] (the `.animate()` wrapper), and Fluvie's own
/// [CollectibleChildren] wrappers (`DeviceFrame`/`Frame`/`Snapshot`, which are
/// `StatelessWidget`s the shape match cannot otherwise see into). Other widgets
/// are leaves to the walk: it never mounts or builds anything.
void walkWidgetTree(Widget widget, void Function(Widget widget) visit) {
  visit(widget);
  for (final child in declaredChildren(widget)) {
    walkWidgetTree(child, visit);
  }
}

/// The children [walkWidgetTree] descends into, in build order — one source
/// of truth for what the structural walk can see, shared by every collector
/// and by the timeline introspector's scoped walk. Widgets outside the
/// walkable shapes return an empty list: they are leaves.
List<Widget> declaredChildren(Widget widget) => switch (widget) {
  CollectibleChildren(:final collectibleChildren) => List.unmodifiable(collectibleChildren),
  MotionTarget(:final child) => [child],
  MultiChildRenderObjectWidget(:final children) => children,
  SingleChildRenderObjectWidget(:final child?) => [child],
  ProxyWidget(:final child) => [child],
  _ => const [],
};
