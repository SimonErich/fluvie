// Compiled, tested snippets for the audio-and-captions docs. They
// live here, not hand-typed in Markdown, so the documentation never drifts from
// a real API. Each `#docregion` flows into one fence via a
// `<!-- code-excerpt -->` marker.

import 'package:flutter/widgets.dart' hide Animation, Image;
import 'package:fluvie/fluvie.dart';

/// The two audio-track constructors, as a reference menu. `path` is an asset
/// key, a file path, or a URL.
List<Audio> audioConstructors(String path) => [
  // #docregion audio-constructors
  Audio.music(path), // a looping or one-shot bed for the whole video
  Audio.sfx(path), // a one-shot effect placed at a moment
  // #enddocregion audio-constructors
];

/// The three caption-source constructors. SRT/VTT parse a file before frame 0;
/// `words` carries inline, per-word timed cues.
List<Captions> captionConstructors(String path, List<CaptionWord> cues) => [
  // #docregion caption-constructors
  Captions.fromSrt(path), // parse a SubRip .srt file
  Captions.fromVtt(path), // parse a WebVTT .vtt file
  Captions.words(cues), // inline, per-word timed cues
  // #enddocregion caption-constructors
];

/// The three caption-style presets.
List<CaptionStyle> captionStyles() => const [
  // #docregion caption-styles
  CaptionStyle.subtitle(), // a plain, readable lower-third band
  CaptionStyle.tikTok(), // bold words that pop in one at a time
  CaptionStyle.karaoke(), // a line that highlights each word as it lands
  // #enddocregion caption-styles
];

/// Where a caption track sits on the canvas.
List<CaptionPosition> captionPositions() => const [
  // #docregion caption-positions
  CaptionPosition.bottomThird(), // the default subtitle band
  CaptionPosition.topThird(), // above the action
  CaptionPosition.center(), // mid-screen
  CaptionPosition.custom(Alignment.bottomCenter, safeArea: 96), // any alignment, with an inset
  // #enddocregion caption-positions
];
