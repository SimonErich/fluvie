import 'package:fluvie/src/composition/runtime/clip_plan_collector.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/elements/snapshot/snapshot.dart';
import 'package:fluvie/src/rendering/video_render_request.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

/// Immutable facts discovered from the mounted Flutter composition.
///
/// Adapters use the same snapshot for export policy, embedded audio and clip
/// windows. It does not own decoded resources; the preparation session does.
final class PreparedComposition {
  /// Copies the facts from a stable preparation generation.
  PreparedComposition({
    required this.video,
    required Iterable<ClipPlan> clipPlans,
    required Iterable<ClipAudioPlan> clipAudioPlans,
    required Iterable<MediaSource> mediaSources,
    required Iterable<Snapshot> snapshots,
    required this.fps,
    required this.totalFrames,
  }) : clipPlans = List.unmodifiable(
         clipPlans.map(
           (plan) => (
             source: plan.source,
             windowStart: plan.windowStart,
             windowLength: plan.windowLength,
             trim: plan.trim,
             speed: plan.speed,
             sourceTimeMap: plan.sourceTimeMap == null
                 ? null
                 : List<double>.unmodifiable(plan.sourceTimeMap!),
           ),
         ),
       ),
       clipAudioPlans = List.unmodifiable(
         clipAudioPlans.map(
           (plan) => (
             source: plan.source,
             startFrame: plan.startFrame,
             windowFrames: plan.windowFrames,
             audio: plan.audio,
             trim: plan.trim,
             speed: plan.speed,
             sourceTimeMap: plan.sourceTimeMap == null
                 ? null
                 : List<double>.unmodifiable(plan.sourceTimeMap!),
           ),
         ),
       ),
       mediaSources = Set.unmodifiable(mediaSources),
       snapshots = List.unmodifiable(snapshots);

  /// The mounted authored video, including videos built by custom widgets.
  final Video? video;

  /// Resolved source-picture windows, including clips inside builders.
  final List<ClipPlan> clipPlans;

  /// Resolved embedded audio windows with authored transition envelopes.
  final List<ClipAudioPlan> clipAudioPlans;

  /// Sources declared by the mounted composition and resource declarations.
  final Set<MediaSource> mediaSources;

  /// In-process snapshots requested by the mounted composition.
  final List<Snapshot> snapshots;

  /// Authored composition clock.
  final int fps;

  /// Complete authored duration, independent of the captured prefix.
  final int totalFrames;

  /// Applies mounted authored output settings to an adapter request.
  VideoRenderRequest resolveRequest(VideoRenderRequest request) {
    final authored = video;
    final poster = authored?.poster?.resolveFrames(
      TimeScopeData(fps: fps, startFrame: 0, durationFrames: totalFrames),
    );
    final outputPoster = poster == null ? null : poster - request.startFrame;
    return request.withAuthoredOptions(
      authoredExport: authored?.export,
      authoredPosterFrame:
          outputPoster != null && outputPoster >= 0 && outputPoster < request.frameCount
          ? outputPoster
          : null,
    );
  }
}
