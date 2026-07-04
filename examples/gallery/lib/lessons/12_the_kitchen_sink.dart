import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_example/lessons/lesson.dart';

/// The brand the whole showcase themes from: one [Palette] and
/// one [TypeScale] flow through `context.fluvie`, so the title and the stat read
/// the accent and the type ladder at the call site.
const _brand = Palette(
  bg: Color(0xFF09090F),
  accent: Color(0xFF7C5CFF),
  onBg: Color(0xFFF4F4FB),
);
final _type = TypeScale.fromBase(44, ratio: 1.3);

/// The committed WAV the music bed plays and the beat pre-pass analyses (reused
/// from lesson 10). The in-house DSP finds the same beat grid on every render,
/// so `Trigger.beat` resolves deterministically with no ffmpeg in the gate.
const _track = 'assets/audio/beat_loop.wav';

/// The committed SubRip file the caption pre-pass reads and parses before frame
/// zero (reused from lesson 10).
const _captions = 'assets/audio/lesson10.srt';

/// Names the music bed so `Trigger.beat(track:)` can reference its beat grid —
/// the same anchor the render plan threads through to the beat resolver.
// #docregion beat-track
final _music = Anchor('music');
// #enddocregion beat-track

/// The animation lists for elements that live inside a per-frame `Builder`,
/// hoisted to stable instances so each frame's rebuild binds the **same**
/// `List<Animation>`. `.animate()`'s animations must be stable across frames
/// (the determinism contract): a fresh list literal inside a per-frame builder
/// re-registers a new token after resolution and throws. The grain effect sits
/// directly in its scene's children (built once), so it keeps its inline list.
final List<Animation> _beatPop = [Animation.pop(at: Trigger.beat(track: _music))];
final List<Animation> _titleFade = [Animation.fadeIn()];
final List<Animation> _captionFade = [Animation.fadeIn(delay: const Time.seconds(1.5))];
final List<Animation> _outro = [Animation.blurIn(), Animation.fadeOut()];

/// Lesson 12 — the kitchen sink: every Fluvie idea in one reel. A beat-synced
/// pop driven by the music bed, a themed title, an animated counter, captions,
/// transitions, and a pixel effect, all over a single [FluvieTheme] and a single
/// analysed audio track.
///
/// The whole reel renders offline and deterministically: the
/// WAV is decoded and its beat grid found before frame zero, the SRT is parsed,
/// and the frame loop only reads those immutable tables. `Trigger.beat` resolves
/// against the beat grid the render plan mounts, so the
/// pop lands on the beat with no live audio in the frame.
const lesson12TheKitchenSink = Lesson(
  id: '12_the_kitchen_sink',
  title: 'The kitchen sink',
  intro:
      'Everything in one reel: a pop synced to the music beat, a themed title, '
      'an animated counter, captions read from an SRT file, crossFade '
      'transitions, and a pixel effect. One FluvieTheme brands it; one analysed '
      'audio track drives the beat. It all renders offline and deterministically.',
  video: lesson12Video,
);

/// Builds the lesson 12 composition: a three-scene, 6 second vertical reel with
/// a music bed, a caption track, and a beat-synced pop.
///
/// [Audio.music] over the committed WAV is both played (mixed by the encoder)
/// and analysed (the beat pre-pass builds its grid). [Captions.fromSrt] mounts
/// the scene-spanning caption overlay. `poster: 2.seconds` lands on the second
/// scene's counter mid-count.
Video lesson12Video() {
  return Video(
    size: VideoSize.reels,
    poster: 2.seconds,
    transition: Transition.crossFade(0.4.seconds),
    // #docregion music
    audio: [Audio.music(_track, track: _music, fadeOut: const Time.seconds(0.5))],
    // #enddocregion music
    captions: const Captions.fromSrt(_captions, style: CaptionStyle.tikTok()),
    scenes: [
      _beatScene(),
      _counterScene(),
      _outroScene(),
    ],
  );
}

/// Scene 1: a themed title with a brand chip that pops on the music beat.
///
/// The chip's [Animation.pop] starts on [Trigger.beat], so the resolver snaps it
/// to the first analysed beat of the music track — the beat grid the render plan
/// mounts. The title reads the brand accent and the
/// display role from `context.fluvie`.
Scene _beatScene() => Scene(
  duration: 2.seconds,
  background: Background.color(_brand.bg),
  children: [
    Center(
      child: FluvieTheme(
        palette: _brand,
        type: _type,
        child: Builder(
          builder: (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // #docregion beat-pop
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: context.fluvie.brand.accent,
                  borderRadius: BorderRadius.circular(32),
                ),
              ).animate(_beatPop),
              // #enddocregion beat-pop
              const SizedBox(height: 48),
              Text(
                'On the beat',
                style: context.fluvie.type.display.copyWith(color: context.fluvie.brand.onBg),
              ).animate(_titleFade),
            ],
          ),
        ),
      ),
    ),
  ],
);

/// Scene 2: an animated [Counter] over a grained backdrop (a pixel effect).
///
/// The [Counter] counts up over the scene; [Animation.grain] lays a seeded,
/// deterministic film grain over the panel (the same seeded noise source the
/// rest of Fluvie reads).
Scene _counterScene() => Scene(
  duration: 2.seconds,
  background: Background.color(_brand.bg),
  children: [
    // #docregion effect
    Positioned.fill(
      child: const ColoredBox(color: Color(0xFF13131F)).animate([
        Animation.grain(0.12),
      ]),
    ),
    // #enddocregion effect
    Center(
      child: FluvieTheme(
        palette: _brand,
        type: _type,
        child: Builder(
          builder: (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // #docregion counter
              Counter(
                to: 12000,
                duration: const Time.seconds(1.5),
                style: context.fluvie.type.display.copyWith(color: context.fluvie.brand.accent),
              ),
              // #enddocregion counter
              const SizedBox(height: 16),
              Text(
                'views and counting',
                style: context.fluvie.type.headline.copyWith(color: context.fluvie.brand.onBg),
              ).animate(_captionFade),
            ],
          ),
        ),
      ),
    ),
  ],
);

/// Scene 3: a themed sign-off that blurs in and fades out.
Scene _outroScene() => Scene.centered(
  duration: 2.seconds,
  background: Background.color(_brand.bg),
  child: FluvieTheme(
    palette: _brand,
    type: _type,
    child: Builder(
      builder: (context) => Text(
        'That is Fluvie',
        textAlign: TextAlign.center,
        style: context.fluvie.type.display.copyWith(color: context.fluvie.brand.accent),
      ).animate(_outro),
    ),
  ),
);
