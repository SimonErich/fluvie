import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/timing/placement/effective_duration.dart';
import 'package:fluvie/src/timing/placement/scene_offset_resolver.dart';
import 'package:fluvie/src/timing/placement/window_resolver.dart';
import 'package:fluvie/src/timing/plan/composition_plan.dart';
import 'package:fluvie/src/timing/plan/element_plan.dart';
import 'package:fluvie/src/timing/resolver/anchor_registry.dart';
import 'package:fluvie/src/timing/resolver/dependency_graph.dart';
import 'package:fluvie/src/timing/resolver/trigger_resolver.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';
import 'package:fluvie/src/timing/timeline/resolved_timeline.dart';
import 'package:fluvie/src/timing/timeline/timeline_anchor.dart';
import 'package:fluvie/src/timing/timeline/timeline_row.dart';

/// Everything the resolution pipeline produced for one plan: the public
/// timeline plus the per-node spans, element windows, registry, and live
/// resolver — what the widget layer and white-box tests need beyond the row
/// table.
typedef ResolvedComposition = ({
  ResolvedTimeline timeline,
  AnchorRegistry registry,
  TriggerResolver resolver,
  Map<int, ResolvedSpan> spans,
  Map<ElementPlan, ResolvedSpan> windows,
});

/// Resolves a whole [plan] to its deterministic schedule: scenes mount
/// back-to-back at running offsets, every element window and animation
/// resolves to absolute frames, and the rows come back sorted by
/// `(startFrame, declaration index)`.
///
/// A pure function — same plan in, same timeline out. Out-of-bounds rows keep
/// their raw spans and surface as [ResolvedTimeline.warnings]; trigger cycles,
/// dangling anchors, and relative scene durations throw a [FluvieTimingError]
/// instead. Overlapping transitions start downstream scenes early and shorten
/// the total.
ResolvedTimeline resolveComposition(CompositionPlan plan) =>
    resolveCompositionDetailed(plan).timeline;

/// [resolveComposition], keeping the pipeline's working state: the single
/// resolution code path behind both the public timeline and the per-node
/// spans the widget layer binds animations to.
ResolvedComposition resolveCompositionDetailed(CompositionPlan plan) {
  // The single source of offset math: scene starts, durations, and
  // transition windows all come from the shared placement resolver.
  final offsets = resolveSceneOffsets(
    fps: plan.fps,
    durations: [for (final scene in plan.scenes) scene.duration],
    transitions: plan.transitions,
    sceneIds: [for (final scene in plan.scenes) scene.id],
  );
  final totalFrames = offsets.totalFrames;
  final root = TimeScopeData(fps: plan.fps, startFrame: 0, durationFrames: totalFrames);

  final windows = <ElementPlan, ResolvedSpan>{};
  final scopes = <ElementPlan, TimeScopeData>{};
  final mergedDefaults = <ElementPlan, Defaults>{};
  for (var s = 0; s < plan.scenes.length; s++) {
    final scene = plan.scenes[s];
    final sceneScope = root.child(
      startFrame: offsets.startFrames[s],
      durationFrames: offsets.durationFrames[s],
    );
    for (final element in scene.elements) {
      final window = resolveElementWindow(element.window, sceneScope);
      windows[element] = ResolvedSpan(window.start, window.end);
      scopes[element] = elementScopeFor(element.window, sceneScope);
      mergedDefaults[element] = mergeDefaultsChain(
        element: element.defaults,
        scene: scene.defaults,
        video: plan.defaults,
        theme: plan.themeDefaults,
      );
    }
  }

  final registry = AnchorRegistry.collect(plan);
  final graph = DependencyGraph.fromRegistry(registry);
  final spans = <int, ResolvedSpan>{};
  final resolver = TriggerResolver(
    plan: plan,
    registry: registry,
    resolved: spans,
    windows: windows,
  );
  for (final node in graph.topologicalOrder()) {
    final scope = scopes[node.element]!;
    spans[node.index] = resolver.resolve(
      node: node,
      elementScope: scope,
      window: windows[node.element]!,
      durationFrames: effectiveDurationFrames(node.plan, mergedDefaults[node.element]!, scope),
      delayFrames: node.plan.delay.resolveFrames(scope),
    );
  }

  final ordered = [...registry.nodes]
    ..sort((a, b) {
      final byStart = spans[a.index]!.start.compareTo(spans[b.index]!.start);
      return byStart != 0 ? byStart : a.index.compareTo(b.index);
    });
  final rows = <TimelineRow>[];
  final warnings = <String>[];
  for (final node in ordered) {
    final span = spans[node.index]!;
    rows.add(
      TimelineRow(
        ownerId: node.element.ownerId,
        phase: node.plan.phase,
        startFrame: span.start,
        endFrame: span.end,
        label: node.plan.label,
      ),
    );
    _checkBounds(node, span, windows[node.element]!, totalFrames, warnings);
  }
  final timeline = ResolvedTimeline(
    fps: plan.fps,
    totalFrames: totalFrames,
    rows: List.unmodifiable(rows),
    anchors: List.unmodifiable([
      for (final anchor in registry.anchors)
        TimelineAnchor(
          name: anchor.debugName ?? anchor.toString(),
          frame: resolver.anchorTimeline(anchor).start,
        ),
    ]),
    warnings: List.unmodifiable(warnings),
  );
  return (
    timeline: timeline,
    registry: registry,
    resolver: resolver,
    spans: spans,
    windows: windows,
  );
}

/// Appends one warning per bounds violation, naming the owner. The row's raw
/// span stays untouched — warnings inform, never clamp.
void _checkBounds(
  AnimationNode node,
  ResolvedSpan span,
  ResolvedSpan window,
  int totalFrames,
  List<String> warnings,
) {
  final label = node.plan.label;
  final what =
      "'${node.element.ownerId}' ${node.plan.phase.name}"
      '${label == null ? '' : " '$label'"}';
  if (span.end < span.start) {
    warnings.add(
      '$what: frames ${span.start}..${span.end} are inverted — the trigger fires '
      'at or after the window end',
    );
  }
  if (span.start < window.start || span.end > window.end) {
    warnings.add(
      '$what: frames ${span.start}..${span.end} overhang the element window '
      '${window.start}..${window.end}',
    );
  }
  if (span.start < 0 || span.end > totalFrames) {
    warnings.add(
      '$what: frames ${span.start}..${span.end} lie outside the video 0..$totalFrames',
    );
  }
}
