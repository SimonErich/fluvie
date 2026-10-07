// Compiled, tested snippets for documentation/guides/authoring-with-specs.md.
// Each `#docregion` flows into one fence via a `<!-- code-excerpt -->` marker,
// so the page can never drift from the real serialization API.

import 'dart:convert';

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';

/// Loads a spec document (JSON text) and builds a renderable [Video].
Video loadSpec(String jsonText) {
  // #docregion load
  final spec = VideoSpec.fromJson(jsonDecode(jsonText) as Map<String, Object?>);
  final video = buildVideo(spec);
  // #enddocregion load
  return video;
}

/// Serializes a spec back to JSON text.
String saveSpec(VideoSpec spec) {
  // #docregion save
  final jsonText = jsonEncode(spec.toJson());
  // #enddocregion save
  return jsonText;
}

/// The stable content digest, for caching and reproducible output.
String specDigest(VideoSpec spec) {
  // #docregion digest
  final id = spec.digest();
  // #enddocregion digest
  return id;
}

/// The widget spelling of an element's effect stack, keyframed and all.
Widget effectStack(Widget child) {
  // #docregion effect-stack
  return child.effects([
    Effect.grain(amount: 0.35),
    Effect.spec(
      EffectSpec(
        EffectSpecKind.vignette,
        params: {
          'amount': KeyframedNumber.linear(
            values: const [0, 0.9],
            positions: const [Time.zero, Time.frames(90)],
          ),
        },
      ),
    ),
  ]);
  // #enddocregion effect-stack
}

/// A partially mixed grade followed by a master tone curve.
Widget colourGrade(Widget child) {
  // #docregion colour-grade
  return child.effects([
    Effect.grade(exposure: 0.2, contrast: 1.08, intensity: 0.6),
    Effect.curves(master: ToneCurve.fromPoints(const [(0, 0), (0.5, 0.55), (1, 1)])),
  ]);
  // #enddocregion colour-grade
}

// #docregion title-motion
Widget titleMotion() =>
    SplitText(
      'Your next great story',
      style: const TextStyle(fontSize: 54, fontWeight: FontWeight.bold),
    ).animate([
      Animation.slideFadeIn(
        duration: const Time.frames(30),
        ease: const Cubic(0.2, 0.9, 0.6, 1),
        stagger: const Stagger.each(Time.frames(4)),
      ),
    ]);
// #enddocregion title-motion

/// Typed encoder settings used by the delivery guide.
Export deliveryEncoderSettings() {
  // #docregion delivery-encoder
  const settings = Export.mp4(
    codec: ExportCodec.h265,
    crf: 21,
    preset: EncoderPreset.fast,
    pixelFormat: ExportPixelFormat.yuv420p10le,
  );
  // #enddocregion delivery-encoder
  return settings;
}

/// A shared-keyframe volume envelope for the editor audio guide.
Audio automatedMusic() {
  // #docregion audio-automation
  final music = Audio.music(
    'audio/bed.wav',
    automation: AudioAutomation(
      values: const [1, 0.25, 1],
      positions: [0.frames, 1.seconds, 4.seconds],
      easings: const [Ease.smooth, Ease.linear],
    ),
  );
  // #enddocregion audio-automation
  return music;
}
