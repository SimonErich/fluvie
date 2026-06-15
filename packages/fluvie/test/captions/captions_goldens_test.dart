// WI-19 (D-CaptionsRender, §17): the caption goldens. The caption layer is
// frame-driven, so each scenario mounts the same cues under a fixture resolver
// at a different frame: an SRT-style subtitle cue, a tikTok word-pop mid-pop,
// and a karaoke highlight. Ahem in ci goldens keeps the text font-free and
// byte-stable.
@Tags(['golden'])
library;

import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/captions/caption_style.dart';
import 'package:fluvie/src/captions/captions.dart';
import 'package:fluvie/src/captions/runtime/captions_layer.dart';
import 'package:fluvie/src/core/captions/caption_cue.dart';
import 'package:fluvie/src/core/captions/caption_source.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/media/runtime/image_resolver_scope.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';

import '../rendering/fakes/fake_media_resolver.dart';

const _scope = TimeScopeData(fps: 30, startFrame: 0, durationFrames: 300);
const _source = CaptionSource.srt('en.srt');

List<CaptionCue> _cues() => [
  CaptionCue('HELLO WORLD', start: 0.0.seconds, end: 2.seconds),
  CaptionCue(
    'SING ALONG NOW',
    start: 2.seconds,
    end: 5.seconds,
    words: [
      CaptionCueWord('SING', at: 2.seconds),
      CaptionCueWord('ALONG', at: 3.seconds),
      CaptionCueWord('NOW', at: 4.seconds),
    ],
  ),
];

Widget _subject(Captions captions, int frame) {
  final resolver = FakeMediaResolver(const {}, captionCues: {_source: _cues()});
  // The fake's pre-resolve has no real await, so it sets its ready flag
  // synchronously before returning; the golden mounts a resolved resolver.
  unawaited(resolver.preResolveCaptions(_source));
  return ExcludeSemantics(
    child: SizedBox(
      width: 360,
      height: 160,
      child: ColoredBox(
        color: const Color(0xFF202020),
        child: ImageResolverScope(
          resolver: resolver,
          child: TimeScopeProvider(
            scope: _scope,
            child: FrameProvider(
              frame: frame,
              child: CaptionsLayer(captions: captions),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> main() async {
  await goldenTest(
    'Captions: an SRT subtitle cue, a tikTok word-pop, and a karaoke highlight',
    fileName: 'captions_layer',
    builder: () => GoldenTestGroup(
      children: [
        GoldenTestScenario(
          name: 'subtitle',
          child: _subject(const Captions.fromSrt('en.srt', style: CaptionStyle.subtitle()), 30),
        ),
        GoldenTestScenario(
          name: 'word-pop mid-pop',
          child: _subject(const Captions.fromSrt('en.srt', style: CaptionStyle.tikTok()), 63),
        ),
        GoldenTestScenario(
          name: 'karaoke highlight',
          child: _subject(const Captions.fromSrt('en.srt', style: CaptionStyle.karaoke()), 100),
        ),
      ],
    ),
  );
}
