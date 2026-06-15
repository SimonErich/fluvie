// WI-20 (D-CaptionsRender, §17): the caption collect pass. A Video with a
// caption track exposes its CaptionSource for the pre-resolve pass; a track-less
// Video exposes none.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/captions/captions.dart';
import 'package:fluvie/src/composition/runtime/caption_collector.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/captions/caption_source.dart';
import 'package:fluvie/src/core/time_extensions.dart';

Video _video(Captions captions) => Video(
  captions: captions,
  scenes: [Scene(duration: 5.seconds)],
);

Video _bareVideo() => Video(
  scenes: [Scene(duration: 5.seconds)],
);

void main() {
  group('collectCaptionSource', () {
    test('returns the track CaptionSource when a Video declares one', () {
      final video = _video(const Captions.fromSrt('en.srt'));
      expect(collectCaptionSource(video), const CaptionSource.srt('en.srt'));
    });

    test('returns null when a Video declares no captions', () {
      expect(collectCaptionSource(_bareVideo()), isNull);
    });
  });
}
