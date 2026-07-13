import 'package:fluvie/fluvie.dart';
import 'package:fluvie_presenter/src/stepping/slide_plan.dart';
import 'package:fluvie_presenter/src/stepping/step_compile_error.dart';
import 'package:fluvie_presenter/src/stepping/stop.dart';

/// Compiles [video] into one [SlidePlan] per scene: the ordered build steps
/// the presentation traverses.
///
/// Pure and deterministic — a structural walk over the declared scenes plus
/// fluvie's static timeline introspection, no widgets mounted. Stops order
/// by document position unless they declare an explicit [Stop.order]; each
/// step's entrance length comes from its elements' introspected enter spans,
/// measured scene-relative so it applies from the reveal moment.
///
/// Throws a [StepCompileError] for setups a presentation cannot run: a
/// duplicate explicit order, cross-element or beat triggers on elements
/// inside a `Stop` (revealed steps resolve locally), or a deck whose
/// timeline does not resolve.
List<SlidePlan> compileSlidePlans(Video video) {
  final TimelineIntrospection introspection;
  try {
    introspection = introspectTimeline(video);
  } on FluvieTimingError catch (error) {
    throw StepCompileError(
      "the deck's timeline does not resolve: ${error.message} Presentations "
      'resolve without beat grids or embedder scopes, so the deck must stand '
      'on its own.',
    );
  }
  return List.unmodifiable([
    for (var s = 0; s < video.scenes.length; s++) _compileScene(video.scenes[s], s, introspection),
  ]);
}

SlidePlan _compileScene(Scene scene, int sceneIndex, TimelineIntrospection introspection) {
  final stops = <Stop>[];
  for (final child in scene.children) {
    walkWidgetTree(child, (widget) {
      if (widget is Stop) stops.add(widget);
    });
  }
  _rejectDuplicateOrders(stops, sceneIndex);
  final ordered =
      List<({Stop stop, int doc})>.unmodifiable([
        for (var i = 0; i < stops.length; i++) (stop: stops[i], doc: i),
      ]).toList()..sort((a, b) {
        final byOrder = (a.stop.order ?? a.doc).compareTo(b.stop.order ?? b.doc);
        return byOrder != 0 ? byOrder : a.doc.compareTo(b.doc);
      });

  final sceneStart = introspection.scenes[sceneIndex].span.start;
  final ownElements = {
    for (final stop in stops) stop: _ownElements(stop, introspection),
  };
  for (final stop in stops) {
    _rejectCompositionTriggers(introspection.elementsIn(stop), sceneIndex);
  }
  final stopped = {for (final elements in ownElements.values) ...elements};
  final baseElements = introspection.scenes[sceneIndex].elements.where(
    (element) => !stopped.contains(element),
  );

  int settle(Iterable<ElementIntrospection> elements) {
    var latest = 0;
    for (final element in elements) {
      final enter = element.enterSpan;
      if (enter == null) continue;
      final relative = enter.end - sceneStart;
      if (relative > latest) latest = relative;
    }
    return latest;
  }

  return SlidePlan(
    sceneIndex: sceneIndex,
    steps: List.unmodifiable([
      SlideStep(index: 0, stops: const [], entranceFrames: settle(baseElements)),
      for (var k = 0; k < ordered.length; k++)
        SlideStep(
          index: k + 1,
          stops: List.unmodifiable([ordered[k].stop]),
          entranceFrames: settle(ownElements[ordered[k].stop]!),
        ),
    ]),
  );
}

/// The elements a stop reveals itself — everything below it except what a
/// nested stop reveals at its own, later step.
Set<ElementIntrospection> _ownElements(Stop stop, TimelineIntrospection introspection) {
  final all = introspection.elementsIn(stop).toSet();
  walkWidgetTree(stop, (widget) {
    if (widget is Stop && !identical(widget, stop)) {
      all.removeAll(introspection.elementsIn(widget));
    }
  });
  return all;
}

void _rejectDuplicateOrders(List<Stop> stops, int sceneIndex) {
  final seen = <int>{};
  for (final stop in stops) {
    final order = stop.order;
    if (order == null) continue;
    if (!seen.add(order)) {
      throw StepCompileError(
        'two stops in scene $sceneIndex declare order $order — every explicit '
        'order must be unique within its scene.',
      );
    }
  }
}

void _rejectCompositionTriggers(List<ElementIntrospection> elements, int sceneIndex) {
  for (final element in elements) {
    for (final animation in element.animations) {
      final at = animation.at;
      if (at is WhenEndsTrigger || at is WhenStartsTrigger || at is BeatTrigger) {
        throw StepCompileError(
          "'${element.ownerId}' in scene $sceneIndex sits inside a Stop, and "
          'revealed steps resolve locally: cross-element and beat triggers '
          'cannot fire there. Use a delay (or Trigger.previous on the same '
          'element) instead.',
        );
      }
    }
  }
}
