import 'package:flutter/widgets.dart';
import 'package:fluvie/src/composition/runtime/clip_plan_collector.dart';
import 'package:fluvie/src/core/contracts/clip_timeline_resolver.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/elements/runtime/clip_frame_planner.dart';
import 'package:fluvie/src/elements/runtime/clip_resampler.dart';
import 'package:fluvie/src/media/runtime/clip_resolve_cache.dart';
import 'package:fluvie/src/rendering/collect_composition_media.dart';

/// Resolves only the frames a preview requests. Unlike an export pre-pass, a
/// ten-minute source never needs ten minutes of decoded RGBA before editing.
final class PreviewClipFrames {
  /// Collects clip timing from [composition] and caches frames in [resolver].
  PreviewClipFrames(this.resolver, this.composition) : lookaheadFrames = 0;

  /// Uses clip windows discovered from actual mounted Flutter elements.
  PreviewClipFrames.fromPlans(
    this.resolver,
    Iterable<ClipPlan> plans, {
    required int fps,
    this.lookaheadFrames = 0,
  })
    // Keep the public named fps argument while storing the private clock.
    : composition = const SizedBox.shrink(),
       // Public constructor keeps fps named without exposing its backing field.
       // ignore: prefer_initializing_formals
       _fps = fps {
    _plans.addAll(plans);
  }

  /// Resolver whose lifetime is owned by the surrounding preview scope.
  final MediaResolver resolver;

  /// The authored composition being previewed.
  final Widget composition;

  /// Bounded sequential decode-ahead; preview seeks use zero, exports use 15.
  final int lookaheadFrames;
  final List<ClipPlan> _plans = [];
  final Map<MediaSource, Set<int>> _ready = {};
  int _fps = 30;
  static const int _batchByteBudget = 32 * 1024 * 1024;

  /// Source frames that can be painted synchronously.
  Map<MediaSource, Set<int>> get ready => {
    for (final entry in _ready.entries) entry.key: Set.of(entry.value),
  };

  /// Collects real clip windows and probes each distinct source.
  Future<void> initialize() async {
    final video = compositionVideo(composition);
    if (video == null) return;
    _fps = video.fps;
    _plans.addAll(
      collectClipPlans(
        video.scenes,
        _fps,
        sceneStartFrames: video.sceneStartFrames,
        overlays: video.overlays,
        totalFrames: video.totalFrames,
      ),
    );
    for (final source in _plans.map((plan) => plan.source).toSet()) {
      await resolver.probeClip(source);
    }
  }

  /// Resolves all source frames required to paint composition [frame].
  Future<void> prepare(int frame) async {
    final wanted = <MediaSource, Set<int>>{};
    final active = <MediaSource>{};
    for (final plan in _plans) {
      if (plan.windowLength <= 0 || frame < plan.windowStart) continue;
      final meta = resolver.clipMetadataFor(plan.source);
      final timeline = clipTimelineFor(resolver, plan.source);
      final bounds = resolveClipTrimBounds(plan.trim, meta, timeline: timeline);
      final offsets = resolveClipTrimOffsets(plan.trim, meta, timeline: timeline);
      int at(int compFrame) => resampleClipFrame(
        compFrame: compFrame,
        windowStart: plan.windowStart,
        compFps: _fps,
        srcFps: meta.fps,
        timeline: timeline,
        trimStartFrames: bounds.start,
        trimEndFrames: bounds.end,
        trimStartOffsetFrames: offsets.start - bounds.start,
        trimEndOffsetFrames: offsets.end - bounds.end,
        speed: plan.speed,
        sourceTimeMap: plan.sourceTimeMap,
      );
      final end = plan.windowStart + plan.windowLength - 1;
      final requested = wanted.putIfAbsent(plan.source, () => {});
      // Held transitions can seek directly to a window's final visible picture.
      // After the window ends retain that endpoint, without traversing the
      // inactive source as the composition clock advances. Future windows need
      // only probed geometry until they become visible.
      final current = at(frame.clamp(plan.windowStart, end));
      requested.add(current);
      if (frame <= end) active.add(plan.source);
      if (frame >= plan.windowStart &&
          frame <= end &&
          !(_ready[plan.source]?.contains(current) ?? false)) {
        final capacity = (_batchByteBudget ~/ (meta.width * meta.height * 4)).clamp(1, 16);
        final ahead = lookaheadFrames.clamp(0, capacity - 1);
        for (var next = frame + 1; next <= frame + ahead && next <= end; next++) {
          requested.add(at(next));
        }
      }
    }
    for (final entry in wanted.entries) {
      final recent = _ready.putIfAbsent(entry.key, () => {});
      final missing = entry.value.where((index) => !recent.contains(index)).toList()..sort();
      final meta = resolver.clipMetadataFor(entry.key);
      final capacity = (_batchByteBudget ~/ (meta.width * meta.height * 4)).clamp(1, 16);
      for (var start = 0; start < missing.length; start += capacity) {
        final end = (start + capacity).clamp(0, missing.length);
        await resolver.preResolveClip(entry.key, missing.sublist(start, end));
      }
      // Keep a short scrub cache. Touching a frame moves it to the newest end.
      for (final frame in entry.value) {
        recent
          ..remove(frame)
          ..add(frame);
      }
      // Inactive sources retain just the endpoints still needed for held
      // pictures. Active sources apply the RGBA budget to their scrub cache as
      // well as decode batches. Simultaneously visible pictures take priority.
      final retained = active.contains(entry.key) ? capacity : 1;
      while (recent.length > retained && recent.length > entry.value.length) {
        recent.remove(recent.firstWhere((value) => !entry.value.contains(value)));
      }
    }
  }

  /// Called after the new image has been painted, when old RawImages no
  /// longer own an evicted handle. Injected resolvers may keep their own cache.
  void evict() {
    final cache = resolver;
    if (cache is ClipResolveCache) {
      (cache as ClipResolveCache).retainPreviewClipFrames(_ready);
    }
  }
}
