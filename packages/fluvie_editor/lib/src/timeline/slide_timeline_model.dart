import 'dart:ui' show Color;

import 'package:fluvie/fluvie.dart'
    show
        AnchorTable,
        AnimationPhase,
        AnimationSpec,
        Ease,
        ElementIntrospection,
        SceneIntrospection,
        Time,
        TimeScope,
        decodeTime,
        introspectTimeline;
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/timeline/keyframe_stop_math.dart';
import 'package:fluvie_editor/src/timeline/step_boundaries.dart';
import 'package:fluvie_editor/src/timeline/timeline_link_palette.dart';
import 'package:fluvie_editor/src/widgets/track_timeline/timeline_bar.dart';
import 'package:fluvie_editor/src/widgets/track_timeline/timeline_diamond.dart';
import 'package:fluvie_editor/src/widgets/track_timeline/timeline_link.dart';
import 'package:fluvie_editor/src/widgets/track_timeline/timeline_marker.dart';
import 'package:fluvie_editor/src/widgets/track_timeline/timeline_track.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart' show validateStepPlan;
import 'package:meta/meta.dart';

part 'slide_timeline_builder.dart';
part 'slide_timeline_links_builder.dart';
part 'slide_timeline_reveal.dart';
part 'slide_timeline_steps.dart';

/// The phase colors a slide timeline paints its bars with: entrances,
/// ambient emphasis (`during`), and exits.
@immutable
final class TimelinePhasePalette {
  /// Creates the palette.
  const TimelinePhasePalette({required this.enter, required this.during, required this.exit});

  /// The entrance color.
  final Color enter;

  /// The ambient/emphasis color.
  final Color during;

  /// The exit color.
  final Color exit;

  @override
  bool operator ==(Object other) =>
      other is TimelinePhasePalette &&
      other.enter == enter &&
      other.during == during &&
      other.exit == exit;

  @override
  int get hashCode => Object.hash(TimelinePhasePalette, enter, during, exit);
}

/// Joins one timeline bar back to the document animation it displays,
/// carrying the resolved timing the panel edits against.
@immutable
final class TimelineBarBinding {
  /// Creates the binding.
  const TimelineBarBinding({
    required this.elementId,
    required this.index,
    required this.delayFrames,
    required this.durationFrames,
    this.stopFrames,
  });

  /// The document element owning the animation.
  final String elementId;

  /// The animation's position in the element's `animate` list.
  final int index;

  /// The authored delay, resolved to scene-relative frames (0 when none).
  final int delayFrames;

  /// The resolved duration in frames (the introspected span's length).
  final int durationFrames;

  /// The resolved bar-relative frame of every keyframe stop, or `null` for
  /// a bar that is not the keyframes form.
  final List<int>? stopFrames;
}

/// Joins one keyframe diamond back to the stop it displays: the bar it
/// rides (whose [TimelineBarBinding] names the element and animation) and
/// the stop index inside the `keyframes` list.
@immutable
final class TimelineDiamondBinding {
  /// Creates the binding.
  const TimelineDiamondBinding({required this.barId, required this.stop});

  /// The bar the diamond rides.
  final String barId;

  /// The stop's index in the animation's `keyframes` list.
  final int stop;
}

/// The track-timeline model of one slide, built from the document and its
/// introspection: one track per element in layers order (topmost first,
/// group children indented), one phase-colored bar per animation positioned
/// on the introspected span made slide-relative, one diamond per keyframe
/// stop of a keyframes-form bar.
///
/// The model is display data plus [bindings] and [diamondBindings] — the
/// joins the panel uses to turn a bar or diamond edit back into a
/// scene-relative document command. Strictly one direction: the document
/// renders into this model, edits dispatch commands, and the next build
/// starts from the changed document.
final class SlideTimelineModel {
  SlideTimelineModel._({
    required this.tracks,
    required this.bindings,
    required this.diamondBindings,
    required this.links,
    required this.markers,
    required this.stepLayout,
    required this.validationMessage,
    required this.totalFrames,
    required this.fps,
  });

  /// Builds the model for [slide] of [document], coloring bars by phase
  /// through [palette] and trigger links through [linkPalette].
  factory SlideTimelineModel.build({
    required EditorDocument document,
    required int slide,
    required TimelinePhasePalette palette,
    required TimelineLinkPalette linkPalette,
  }) {
    final scene = introspectTimeline(document.spec.build()).scenes[slide];
    final steps = _SlideSteps.compute(document, slide, scene);
    final builder = _ModelBuilder(
      document,
      scene.span.start,
      scene.span.durationFrames,
      palette,
      scene.elementById,
      steps.steppedIds,
    );
    for (final id in document.elementIdsInScene(slide).reversed) {
      builder.addTrack(id, depth: 0);
      for (final childId in document.childIdsOfGroup(id).reversed) {
        builder.addTrack(childId, depth: 1);
      }
    }
    return SlideTimelineModel._(
      tracks: List.unmodifiable(builder.tracks),
      bindings: Map.unmodifiable(builder.bindings),
      diamondBindings: Map.unmodifiable(builder.diamondBindings),
      links: List.unmodifiable(builder.buildLinks(linkPalette)),
      markers: steps.markers,
      stepLayout: steps.layout,
      validationMessage: steps.validationMessage,
      totalFrames: scene.span.durationFrames,
      fps: document.spec.fps,
    );
  }

  /// The rows, topmost element first, group children after their group.
  final List<TimelineTrack> tracks;

  /// The document join per bar id.
  final Map<String, TimelineBarBinding> bindings;

  /// The document join per diamond id (keyframes-form bars only).
  final Map<String, TimelineDiamondBinding> diamondBindings;

  /// The trigger links between bars. A link's id IS its source bar id, so
  /// [bindings] joins a link back to its animation.
  final List<TimelineLink> links;

  /// The build-step markers, one per listed step, in exact parity with the
  /// presenter's `compileSlidePlans` settle frames.
  final List<TimelineMarker> markers;

  /// The step membership and reveal ends behind [markers] — what marker
  /// gestures partition against.
  final SlideStepLayout stepLayout;

  /// The first `validateStepPlan` problem, or null for a clean deck — the
  /// panel's one-line explanation of flagged bars.
  final String? validationMessage;

  /// The slide's length in frames.
  final int totalFrames;

  /// The deck's frames per second.
  final int fps;

  /// Whether any track carries a bar — false is the empty-timeline state.
  bool get hasBars => tracks.any((track) => track.bars.isNotEmpty);
}
