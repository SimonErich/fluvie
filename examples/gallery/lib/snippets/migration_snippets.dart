// Compiled, tested snippets for documentation/reference/migration.md. The old
// forms are shown illustratively in the page (code-excerpt-ignore); only the
// new forms compile here, so the migration target can never drift from the API.
// Each `#docregion` flows into one fence via a `<!-- code-excerpt -->` marker.

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';

const _line = TextStyle(color: Color(0xFFE6EDF3), fontSize: 40);

/// The new motion form: one `.animate([...])` list instead of the old
/// `AnimatedProp` / `PropAnimation` / `EntryAnimation` widgets.
Widget migrateAnimate() =>
    // #docregion migrate-animate
    const Text('Hello', style: _line).animate([Animation.slideFade()]);
// #enddocregion migrate-animate

/// The new stagger form: a `stagger:` on the animation, not a `Stagger` widget.
Widget migrateStagger() =>
    // #docregion migrate-stagger
    const Column(children: [Text('A'), Text('B')]).animate([
      Animation.fadeIn(stagger: const Stagger.each(Time.frames(6))),
    ]);
// #enddocregion migrate-stagger

/// The new layout form: real Flutter widgets, no `V`-prefixed wrappers.
Widget migrateLayout() =>
    // #docregion migrate-layout
    const Column(
      children: [
        Text('Plain Flutter', style: _line),
        Text('Row, Column, Stack, Center', style: _line),
      ],
    );
// #enddocregion migrate-layout

/// The new effects form: pixel post-effects sit in the same `.animate([...])`
/// list, not in a separate `EffectOverlay` / `ParticleEffect` tree.
Widget migrateEffects() =>
    // #docregion migrate-effects
    const ColoredBox(color: Color(0xFF13131F)).animate([
      Animation.grain(0.12),
      Animation.vignette(0.4),
    ]);
// #enddocregion migrate-effects

/// The new image form: one `Image` plus `Animation.kenBurns` and `Frame.*`,
/// replacing `KenBurnsImage` / `PhotoCard` / `PolaroidFrame`.
Widget migrateImage(String url) =>
    // #docregion migrate-image
    Frame.polaroid(
      child: Image.network(url, fit: BoxFit.cover).animate([Animation.kenBurns()]),
    );
// #enddocregion migrate-image

/// The new repeat form: a `repeat:` on the animation, not a `Loop` widget.
Widget migrateLoop() =>
    // #docregion migrate-loop
    const Text('Spinning', style: _line).animate([
      Animation.spin(repeat: const Repeat.forever()),
    ]);
// #enddocregion migrate-loop

/// The new clip form: one `Clip`, replacing `EmbeddedVideo` / `VideoSequence`.
Widget migrateClip(Uri url) =>
    // #docregion migrate-clip
    Clip.network(url, audio: const ClipAudio.muted(), fit: BoxFit.cover);
// #enddocregion migrate-clip

/// The new audio form: `Audio.music` / `Audio.sfx`, replacing `AudioTrack` /
/// `BackgroundAudio`.
List<Audio> migrateAudio(String path) => [
  // #docregion migrate-audio
  Audio.music(path, fadeOut: const Time.seconds(0.5)),
  // #enddocregion migrate-audio
];

/// The new export form: `Export.*`, replacing `EncodingConfig`.
Export migrateExport() =>
    // #docregion migrate-export
    const Export.mp4(quality: Quality.max);
// #enddocregion migrate-export
