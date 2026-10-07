import 'package:flutter/widgets.dart' as flutter;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart' show ClipMetadata, probeTrimmedClips;

import 'fakes/fake_media_resolver.dart';

/// A resolver that records what it was asked to probe, so the test can assert
/// the pass probes only what the mix actually needs.
final class _CountingResolver extends FakeMediaResolver {
  _CountingResolver(super.canned, {super.metadata});

  final List<MediaSource> probes = [];

  @override
  Future<ClipMetadata> probeClip(MediaSource source) {
    probes.add(source);
    return super.probeClip(source);
  }
}

void main() {
  const meta = (fps: 30.0, frameCount: 300, width: 16, height: 9, hasAudio: true);
  const cam = MediaSource.asset('clips/cam.mp4');

  test('a composition that is not a Video probes nothing', () async {
    final resolver = _CountingResolver(const {});
    final probed = await probeTrimmedClips(
      const flutter.SizedBox(),
      resolver: resolver,
      fps: 30,
    );
    expect(probed, isEmpty);
    expect(resolver.probes, isEmpty);
  });

  test('an untrimmed clip needs no probe', () async {
    final resolver = _CountingResolver(const {}, metadata: {cam: meta});
    final video = Video(
      size: VideoSize.square,
      scenes: [
        Scene(duration: 2.seconds, children: [Clip.asset('clips/cam.mp4')]),
      ],
    );

    final probed = await probeTrimmedClips(video, resolver: resolver, fps: 30);

    // Its audio opens at the head of the file, which needs no source facts.
    expect(probed, isEmpty);
    expect(resolver.probes, isEmpty);
  });

  test('a trimmed clip is probed once however often it appears', () async {
    final resolver = _CountingResolver(const {}, metadata: {cam: meta});
    final video = Video(
      size: VideoSize.square,
      scenes: [
        Scene(
          duration: 2.seconds,
          children: [Clip.asset('clips/cam.mp4', trim: 2.seconds.to(7.seconds))],
        ),
        Scene(
          duration: 2.seconds,
          children: [Clip.asset('clips/cam.mp4', trim: 1.seconds.to(4.seconds))],
        ),
      ],
    );

    final probed = await probeTrimmedClips(video, resolver: resolver, fps: 30);

    expect(probed, {cam: meta});
    expect(resolver.probes, [cam], reason: 'probing is cached, so one source is one probe');
  });

  test('a muted clip is never probed: its audio never reaches the mix', () async {
    final resolver = _CountingResolver(const {}, metadata: {cam: meta});
    final video = Video(
      size: VideoSize.square,
      scenes: [
        Scene(
          duration: 2.seconds,
          children: [
            Clip.asset(
              'clips/cam.mp4',
              trim: 2.seconds.to(7.seconds),
              audio: const ClipAudio.muted(),
            ),
          ],
        ),
      ],
    );

    final probed = await probeTrimmedClips(video, resolver: resolver, fps: 30);

    expect(probed, isEmpty);
    expect(resolver.probes, isEmpty);
  });
}
