import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/src/composition/runtime/clip_plan_collector.dart';
import 'package:fluvie/src/rendering/preview_clip_frames.dart';

import 'fakes/fake_media_resolver.dart';

const _source = MediaSource.asset('clip.mp4');

class _RecordingResolver extends FakeMediaResolver {
  _RecordingResolver({int width = 160, int height = 90})
    : super(
        {},
        metadata: {
          _source: (fps: 30, frameCount: 600, width: width, height: height, hasAudio: false),
        },
      );
  final List<List<int>> requests = [];
  @override
  Future<void> preResolveClip(MediaSource source, Iterable<int> sourceFrames) async {
    requests.add(sourceFrames.toList());
  }
}

ClipPlan _plan({int start = 0, int length = 60, double speed = 1}) => (
  source: _source,
  windowStart: start,
  windowLength: length,
  trim: null,
  speed: speed,
  sourceTimeMap: null,
);

Future<_RecordingResolver> _resolver({int width = 160, int height = 90}) async {
  final resolver = _RecordingResolver(width: width, height: height);
  await resolver.preResolveAll([]);
  return resolver;
}

void main() {
  test('sixty sequential frames use four bounded batches and retain current pictures', () async {
    final resolver = await _resolver();
    final frames = PreviewClipFrames.fromPlans(resolver, [_plan()], fps: 30, lookaheadFrames: 15);
    for (var frame = 0; frame < 60; frame++) {
      await frames.prepare(frame);
      expect(frames.ready[_source], contains(frame));
      expect(frames.ready[_source]!.length, lessThanOrEqualTo(16));
    }
    expect(resolver.requests, hasLength(4));
    expect(resolver.requests.expand((batch) => batch), orderedEquals(List.generate(60, (i) => i)));
  });

  test(
    'RGBA source geometry caps extraction batches independently of requested lookahead',
    () async {
      final resolver = await _resolver(width: 3840, height: 2160);
      final frames = PreviewClipFrames.fromPlans(
        resolver,
        [_plan()],
        fps: 30,
        lookaheadFrames: 1000,
      );
      await frames.prepare(0);
      expect(resolver.requests, [
        [0],
      ]);
      expect(
        resolver.requests.single.length * 3840 * 2160 * 4,
        lessThanOrEqualTo(32 * 1024 * 1024),
      );
      await frames.prepare(1);
      expect(frames.ready[_source], {1});
    },
  );

  test(
    'future windows do no extraction and direct held seeks warm the last visible picture',
    () async {
      final resolver = await _resolver();
      final frames = PreviewClipFrames.fromPlans(resolver, [_plan(start: 20, length: 10)], fps: 30);
      await frames.prepare(0);
      expect(resolver.requests, isEmpty);
      await frames.prepare(35);
      expect(resolver.requests, [
        [9],
      ]);
      await frames.prepare(100);
      expect(resolver.requests, hasLength(1));
      expect(frames.ready[_source], contains(9));
    },
  );

  test('completed sources retain only their held endpoint rather than the scrub batch', () async {
    final resolver = await _resolver();
    final frames = PreviewClipFrames.fromPlans(resolver, [_plan()], fps: 30, lookaheadFrames: 15);
    await frames.prepare(48);
    expect(frames.ready[_source], hasLength(12));
    await frames.prepare(60);
    expect(frames.ready[_source], {59});
    expect(resolver.requests, hasLength(1));
  });

  test('reverse playback batches exact resampled indices and scrub seeks stay ready', () async {
    final resolver = await _resolver();
    final frames = PreviewClipFrames.fromPlans(
      resolver,
      [_plan(length: 8, speed: -1)],
      fps: 30,
      lookaheadFrames: 3,
    );
    await frames.prepare(0);
    expect(resolver.requests.single, [596, 597, 598, 599]);
    await frames.prepare(6);
    expect(frames.ready[_source], contains(593));
    await frames.prepare(0);
    expect(frames.ready[_source], contains(599));
  });
}
