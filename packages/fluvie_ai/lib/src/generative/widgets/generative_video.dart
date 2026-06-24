import 'package:flutter/widgets.dart' show BoxFit, Key;
import 'package:fluvie/fluvie.dart';

/// Provider sugar for an AI-generated video clip.
///
/// Builds the provider-agnostic [GenerativeMedia] with a video [GenerativeSource]
/// so the prerender pass produces it once (cached by prompt + seed + params) and
/// it then plays like a local clip. When the model returns video with an embedded
/// audio track (for example Veo 3, `withAudio: true`), that track joins the mix
/// delayed to the clip's scene window — in sync because it is the same file.
///
/// ```dart
/// GenerativeVideo.veo(prompt: 'a man walking down the street', seconds: 6)
/// ```
abstract final class GenerativeVideo {
  /// A Google Veo video from [prompt], [seconds] long. Veo 3 returns an embedded
  /// audio track; keep it with [withAudio] (the default) or drop it.
  static GenerativeMedia veo({
    required String prompt,
    double? seconds,
    String? seed,
    bool withAudio = true,
    BoxFit? fit,
    Key? key,
  }) => GenerativeMedia(
    source: GenerativeSource.video(
      providerId: 'veo',
      prompt: prompt,
      seed: seed,
      params: {'seconds': ?seconds, 'withAudio': withAudio},
    ),
    audio: withAudio ? const ClipAudio.included() : const ClipAudio.muted(),
    fit: fit,
    key: key,
  );
}
