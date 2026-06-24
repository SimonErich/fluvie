import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/runtime/media_collector.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/core/media/clip_audio.dart';
import 'package:fluvie/src/core/media/generative_source.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/generative_media.dart';

import '../../rendering/fakes/fake_generative_resolver.dart';

const _img = GenerativeSource.image(providerId: 'flux', prompt: 'a');
const _vid = GenerativeSource.video(providerId: 'veo', prompt: 'b');
const _imgFile = MediaSource.file('/cache/a.png');
const _vidFile = MediaSource.file('/cache/b.mp4');

FakeGenerativeResolver _resolver({bool hasAudio = true}) => FakeGenerativeResolver(
  media: {_img: _imgFile, _vid: _vidFile},
  meta: {
    _vid: (duration: const Duration(seconds: 1), hasAudio: hasAudio, width: null, height: null),
  },
);

Scene _scene(List<Widget> children) => Scene(duration: const Time.frames(30), children: children);

void main() {
  group('collectMediaSources is generative-aware', () {
    test('folds a generated image as its produced file source', () {
      final found = collectMediaSources(
        [
          _scene(const [GenerativeMedia(source: _img)]),
        ],
        generative: _resolver(),
      );
      expect(found, contains(_imgFile));
    });

    test('without a resolver, a GenerativeMedia contributes nothing', () {
      final found = collectMediaSources([
        _scene(const [GenerativeMedia(source: _img)]),
      ]);
      expect(found, isEmpty);
    });
  });

  group('collectClipPlans is generative-aware', () {
    test('adds a plan for a generated video with its trim and window', () {
      final plans = collectClipPlans(
        [
          _scene(const [GenerativeMedia(source: _vid)]),
        ],
        30,
        generative: _resolver(),
      );
      expect(plans, hasLength(1));
      expect(plans.single.source, _vidFile);
      expect(plans.single.windowLength, 30);
    });

    test('a generated image is not a clip plan', () {
      final plans = collectClipPlans(
        [
          _scene(const [GenerativeMedia(source: _img)]),
        ],
        30,
        generative: _resolver(),
      );
      expect(plans, isEmpty);
    });

    test('without a resolver, a generated video is skipped', () {
      final plans = collectClipPlans([
        _scene(const [GenerativeMedia(source: _vid)]),
      ], 30);
      expect(plans, isEmpty);
    });
  });

  group('collectClipAudioPlans folds generated-video embedded audio', () {
    test('includes the produced video file delayed to its scene window', () {
      final plans = collectClipAudioPlans(
        [
          _scene(const []),
          _scene(const [GenerativeMedia(source: _vid)]),
        ],
        30,
        generative: _resolver(),
      );
      expect(plans, hasLength(1));
      expect(plans.single.source, _vidFile);
      expect(plans.single.startFrame, 30);
      expect(plans.single.windowFrames, 30);
    });

    test('a muted generated video contributes no audio', () {
      final plans = collectClipAudioPlans(
        [
          _scene(const [GenerativeMedia(source: _vid, audio: ClipAudio.muted())]),
        ],
        30,
        generative: _resolver(),
      );
      expect(plans, isEmpty);
    });

    test('a generated video with no embedded audio contributes nothing', () {
      final plans = collectClipAudioPlans(
        [
          _scene(const [GenerativeMedia(source: _vid)]),
        ],
        30,
        generative: _resolver(hasAudio: false),
      );
      expect(plans, isEmpty);
    });

    test('without a resolver, a generated video contributes no audio', () {
      final plans = collectClipAudioPlans([
        _scene(const [GenerativeMedia(source: _vid)]),
      ], 30);
      expect(plans, isEmpty);
    });
  });
}
