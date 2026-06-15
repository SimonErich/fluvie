// A small structural walker over the declared widget tree a built-in
// VideoTemplate composes. The built-ins nest through the public container
// shapes (Center, Column, Padding, MotionTarget), so the probe descends those
// explicitly — no dynamic reflection — to gather the Texts and MotionTargets a
// test asserts on without mounting a frame clock.

import 'package:flutter/widgets.dart';
import 'package:fluvie/src/animation/motion_target.dart';
import 'package:fluvie/src/composition/video.dart';

/// Every widget of type [T] reachable in the declared scene tree of [video].
List<T> collectWidgets<T extends Widget>(Video video) {
  final found = <T>[];
  _forEachWidget(video, (widget) {
    if (widget is T) found.add(widget);
  });
  return found;
}

/// Every [Text] reachable in the declared scene tree of [video].
List<Text> collectTexts(Video video) => collectWidgets<Text>(video);

/// Every [MotionTarget] reachable in the declared scene tree of [video].
List<MotionTarget> collectMotionTargets(Video video) => collectWidgets<MotionTarget>(video);

/// Visits every widget in [video]'s declared scene trees, descending through
/// the container shapes the built-ins use.
void _forEachWidget(Video video, void Function(Widget) visit) {
  void descend(Widget widget) {
    visit(widget);
    _childrenOf(widget).forEach(descend);
  }

  for (final scene in video.scenes) {
    scene.children.forEach(descend);
  }
}

/// The direct children of [widget] among the container shapes the built-ins use.
Iterable<Widget> _childrenOf(Widget widget) => switch (widget) {
  MotionTarget(:final child) => [child],
  Center(:final child?) => [child],
  Align(:final child?) => [child],
  Padding(:final child?) => [child],
  SizedBox(:final child?) => [child],
  Column(:final children) => children,
  Row(:final children) => children,
  Stack(:final children) => children,
  _ => const <Widget>[],
};
