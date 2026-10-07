// Task 23: preResolveCompositionClips probes every clip in a composition, plans
// the source frames its scene window reads (at the video's own fps, the clock
// the painter resamples against), and extracts them through the resolver before
// the frame loop. A recording resolver captures the calls; the pre-pass only
// ever calls probeClip and preResolveClip.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/contracts/clip_frame_preparer.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/elements/clip.dart';
import 'package:fluvie/src/elements/image.dart' as fluvie;
import 'package:fluvie/src/rendering/pre_resolve_clips.dart';

/// A resolver that records every probe and clip pre-resolution. Every other
/// member is unused by the clip pre-pass; [noSuchMethod] throws if one is hit.
class _RecordingResolver implements MediaResolver {
  _RecordingResolver(this._meta);

  final Map<MediaSource, ClipMetadata> _meta;
  final probed = <MediaSource>[];
  final extracted = <MediaSource, List<int>>{};

  @override
  Future<ClipMetadata> probeClip(MediaSource source) async {
    probed.add(source);
    return _meta[source]!;
  }

  @override
  Future<void> preResolveClip(MediaSource source, Iterable<int> sourceFrames) async {
    extracted[source] = sourceFrames.toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used by the clip pre-pass');
}

/// One registered streaming window, as the pre-pass hands it over.
typedef _Registered = ({
  int windowStart,
  int windowLength,
  int trimStart,
  int trimEnd,
  double speed,
});

/// A recording resolver that also streams, so the test can read back exactly
/// which windows the pre-pass registered for the capture loop to warm.
final class _RecordingPreparer extends _RecordingResolver implements ClipFramePreparer {
  _RecordingPreparer(super._meta);

  final registered = <_Registered>[];

  @override
  void registerClipPlan({
    required MediaSource source,
    required int windowStart,
    required int windowLength,
    required int compFps,
    required int trimStartFrames,
    required int trimEndFrames,
    double trimStartOffsetFrames = 0,
    double trimEndOffsetFrames = 0,
    double speed = 1,
    List<double>? sourceTimeMap,
  }) => registered.add((
    windowStart: windowStart,
    windowLength: windowLength,
    trimStart: trimStartFrames,
    trimEnd: trimEndFrames,
    speed: speed,
  ));

  @override
  Future<void> prepareClipFrames(int compFrame) async {}
}

const _clip = MediaSource.asset('clip.mp4');

void main() {
  test('plans and extracts each clip frame across its scene window', () async {
    final video = Video(
      scenes: [
        Scene(duration: const Time.frames(4), children: [Clip.asset('clip.mp4')]),
      ],
    );
    final resolver = _RecordingResolver({
      _clip: (fps: 30.0, frameCount: 30, width: 2, height: 2, hasAudio: false),
    });

    await preResolveCompositionClips(composition: video, resolver: resolver, totalFrames: 4);

    expect(resolver.probed, [_clip]);
    expect(resolver.extracted[_clip], [0, 1, 2, 3]);
  });

  test('a half-speed source extracts each held frame once', () async {
    final video = Video(
      scenes: [
        Scene(duration: const Time.frames(4), children: [Clip.asset('clip.mp4')]),
      ],
    );
    final resolver = _RecordingResolver({
      _clip: (fps: 15.0, frameCount: 30, width: 2, height: 2, hasAudio: false),
    });

    await preResolveCompositionClips(composition: video, resolver: resolver, totalFrames: 4);

    expect(resolver.extracted[_clip], [0, 1], reason: 'frames 0 and 1 each cover two comp frames');
  });

  test('the video fps drives the scene window the plan covers', () async {
    final video = Video(
      fps: 24,
      scenes: [
        Scene(duration: 1.seconds, children: [Clip.asset('clip.mp4')]),
      ],
    );
    final resolver = _RecordingResolver({
      _clip: (fps: 24.0, frameCount: 30, width: 2, height: 2, hasAudio: false),
    });

    await preResolveCompositionClips(composition: video, resolver: resolver, totalFrames: 24);

    expect(resolver.extracted[_clip], List.generate(24, (i) => i));
  });

  test('a clip held into a later scene extracts the frame it is clamped to', () async {
    // Regression: a clip in scene 1 keeps painting (held on its last source
    // frame) while scene 2 is on screen. The in-window plan floors composition
    // frame 149 to source 148, but off-screen in scene 2 the resampler clamps to
    // the trim end (149) — so 149 must be extracted too, across the whole comp.
    final video = Video(
      scenes: [
        Scene(duration: const Time.frames(150), children: [Clip.asset('clip.mp4')]),
        Scene(duration: const Time.frames(150), children: [fluvie.Image.asset('photo.png')]),
      ],
    );
    final resolver = _RecordingResolver({
      _clip: (fps: 30.0, frameCount: 150, width: 2, height: 2, hasAudio: false),
    });

    await preResolveCompositionClips(
      composition: video,
      resolver: resolver,
      totalFrames: 300,
    );

    expect(resolver.extracted[_clip], contains(149));
  });

  test('the streaming plan registers the window the painter resamples from', () async {
    // ClipPainter reads TimeScopeProvider.startFrame, which WindowScope sets to
    // the element window start. Register the scene start instead and the
    // streamer warms one frame while paint looks up another, missing the
    // bounded window.
    final video = Video(
      scenes: [
        Scene(
          duration: const Time.frames(150),
          children: [
            Clip.asset('clip.mp4').show(from: const Time.frames(30), to: const Time.frames(60)),
          ],
        ),
      ],
    );
    final resolver = _RecordingPreparer({
      _clip: (fps: 30.0, frameCount: 150, width: 2, height: 2, hasAudio: false),
    });

    await preResolveCompositionClips(composition: video, resolver: resolver, totalFrames: 150);

    expect(resolver.registered.single.windowStart, 30);
    expect(resolver.registered.single.windowLength, 30);
  });

  test('two windows on one source are each registered, so both stay warm', () async {
    // The registry used to keep one plan per source, so the second element
    // silently overwrote the first and only one of them warmed correctly.
    final video = Video(
      scenes: [
        Scene(
          duration: const Time.frames(150),
          children: [
            Clip.asset('clip.mp4').show(from: Time.zero, to: const Time.frames(30)),
            Clip.asset('clip.mp4').show(from: const Time.frames(90), to: const Time.frames(120)),
          ],
        ),
      ],
    );
    final resolver = _RecordingPreparer({
      _clip: (fps: 30.0, frameCount: 150, width: 2, height: 2, hasAudio: false),
    });

    await preResolveCompositionClips(composition: video, resolver: resolver, totalFrames: 150);

    expect(resolver.registered.map((plan) => plan.windowStart), [0, 90]);
  });

  test('a window that collapses to nothing still extracts the frame it paints', () async {
    // A show window past the end of its scene clamps to zero length at the
    // scene edge. The element is never unmounted, so its painter still resolves
    // a clamped source frame every composition frame — planning nothing would
    // leave that lookup with no extracted frame and paint would throw.
    final video = Video(
      scenes: [
        Scene(
          duration: const Time.frames(30),
          children: [
            Clip.asset('clip.mp4').show(from: 1.seconds, to: 2.seconds),
          ],
        ),
      ],
    );
    final resolver = _RecordingPreparer({
      _clip: (fps: 30.0, frameCount: 30, width: 2, height: 2, hasAudio: false),
    });

    await preResolveCompositionClips(composition: video, resolver: resolver, totalFrames: 30);

    expect(resolver.extracted[_clip], isNotEmpty);
    expect(resolver.registered, hasLength(1));
  });

  test('a composition with no clips probes and extracts nothing', () async {
    final video = Video(
      scenes: [
        Scene(duration: const Time.frames(4), children: [fluvie.Image.asset('photo.png')]),
      ],
    );
    final resolver = _RecordingResolver(const {});

    await preResolveCompositionClips(composition: video, resolver: resolver, totalFrames: 4);

    expect(resolver.probed, isEmpty);
    expect(resolver.extracted, isEmpty);
  });
}
