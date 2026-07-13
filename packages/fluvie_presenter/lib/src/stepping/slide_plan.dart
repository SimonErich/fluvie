/// @docImport 'package:fluvie_presenter/src/stepping/step_compiler.dart';
library;

import 'package:fluvie_presenter/src/stepping/stop.dart';
import 'package:meta/meta.dart';

/// One scene compiled into its ordered build steps — what the presentation
/// controller traverses and the slide view renders.
///
/// Steps are dense and zero-based: step 0 is the scene's own content, each
/// later step reveals one [Stop]. Produced by [compileSlidePlans].
@immutable
final class SlidePlan {
  /// Creates the plan for one scene; [steps] must start with the base step.
  const SlidePlan({required this.sceneIndex, required this.steps});

  /// The scene this plan describes, as an index into the video's scenes.
  final int sceneIndex;

  /// The ordered steps: index 0 plays on slide entry, the rest reveal on
  /// advance.
  final List<SlideStep> steps;

  /// How many steps the slide has (the number of stops plus one).
  int get stepCount => steps.length;

  @override
  String toString() => 'SlidePlan(scene: $sceneIndex, steps: $stepCount)';
}

/// One build step of a slide: what it reveals and how long its entrance
/// plays.
@immutable
final class SlideStep {
  /// Creates a step; the base step carries no stops.
  const SlideStep({required this.index, required this.stops, required this.entranceFrames});

  /// The step's position within its slide (0 = the base step).
  final int index;

  /// The stops revealed at this step, in reveal order; empty for step 0.
  final List<Stop> stops;

  /// How many frames the step's entrances take to settle, measured from the
  /// reveal moment — the settle skip back navigation applies.
  final int entranceFrames;

  @override
  String toString() =>
      'SlideStep($index, stops: ${stops.length}, entrance: $entranceFrames frames)';
}
