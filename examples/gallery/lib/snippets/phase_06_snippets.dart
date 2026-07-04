// Compiled, tested snippets for the scenes-and-transitions doc. They live here,
// not hand-typed in Markdown, so the documentation never drifts from a real
// API. Each `#docregion` flows into one fence via a `<!-- code-excerpt -->`
// marker.

// The reference menu spells out the default direction/into/from and writes a
// bare Transition.cut() so the doc reads as a plain catalog, which trips the
// redundant-value and const-constructor lints.
// ignore_for_file: avoid_redundant_argument_values, prefer_const_constructors
import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';

/// The five transitions between scenes. Each shares a `Time` and
/// an `Ease`, and names its own geometry.
List<Transition> transitions() => [
  // #docregion transitions
  Transition.cut(),
  Transition.crossFade(0.5.seconds),
  Transition.wipe(0.4.seconds, direction: Edge.right),
  Transition.zoom(0.6.seconds, into: Alignment.center),
  Transition.slide(0.4.seconds, from: Edge.right),
  // #enddocregion transitions
];
