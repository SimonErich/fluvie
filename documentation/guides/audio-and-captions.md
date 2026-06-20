# Audio and captions

Add a music bed, make the picture react to the bass, and burn in subtitles.
Lesson 10 does all three in one scene. Start with the music bed: pass an
`Audio.music` to `Video.audio` and the encoder mixes it under the frames.

<!-- code-excerpt "example/lib/lessons/10_audio_and_captions.dart (music)" -->
```dart
audio: const [
  Audio.music(_track, fadeIn: Time.seconds(0.3), fadeOut: Time.seconds(0.5)),
],
```

That plays `_track` for the length of the video, fades it up over the first 0.3
seconds, and fades it out over the last 0.5 seconds. The picture stays the same;
only the soundtrack changes. The rest of this page covers the three jobs audio
does: it plays, it drives reactive motion, and it sits under captions.

## Audio tracks and mixing

`Video.audio` takes a list of tracks. Each track is one `Audio`:

<!-- code-excerpt "example/lib/snippets/phase_10_snippets.dart (audio-constructors)" -->
```dart
Audio.music(path), // a looping or one-shot bed for the whole video
Audio.sfx(path), // a one-shot effect placed at a moment
```

Every track carries the same controls:

- `volume` scales the track from 0.0 (silent) to 1.0 (full) and above.
- `fadeIn` and `fadeOut` take a `Time` and ramp the track in or out.
- `trim` selects a span of the source file (for example seconds 4 to 12).
- `at` places an `Audio.sfx` at a moment, named by a `Trigger` or a `Time`.

The encoder mixes the tracks. Each track becomes one input with its own trim,
delay, volume, and fade filters, and the encoder sums them with `amix` into the
final soundtrack. A clip's own audio (`ClipAudio.included`) joins the mix as one
more track, so a video clip with sound layers under your music bed without extra
work.

One determinism note. Audio bytes are per-machine. Different FFmpeg builds encode
the same mix to slightly different bytes, so the audio stream of your MP4 can
differ between two machines. The video frames stay byte-identical everywhere. The
picture is the deterministic part; the soundtrack is the per-machine part.

## Beat-reactive motion

You can make elements react to the energy in a frequency band. The reactive
presets read the audio's per-frame energy and drive a transform. Pulse a badge on
the bass band:

<!-- code-excerpt "example/lib/lessons/10_audio_and_captions.dart (pulse)" -->
```dart
.animate([Animation.fadeIn(), Animation.pulse(on: AudioBand.bass, gain: 0.4)]);
```

Each frame the badge scales by `1 + bassEnergy * gain`, so it grows on the kick
and settles between beats. `Animation.scaleY(on:, gain:)` does the same on the Y
axis only, for a bar that stretches vertically with the band. `gain` scales how
far the motion travels.

Three bands are available: `AudioBand.bass`, `AudioBand.mid`, and
`AudioBand.treble`. With no `track`, a reactive preset reads the master mix. Pass
a `track` to read one specific audio track instead.

The `Bars` element draws a frequency visualizer:

<!-- code-excerpt "example/lib/lessons/10_audio_and_captions.dart (bars)" -->
```dart
Widget _bars() => const Bars(count: 32, gain: 1.2);
```

That paints 32 bars whose heights follow the band energy each frame. `count` sets
how many bars, `gain` scales their height, and `band` picks which band to read
(it defaults to `AudioBand.bass`).

### The determinism rule

The frame loop never touches live audio. Every reactive input is analysed once
before frame 0.

Before the first frame, Fluvie decodes the audio file, runs the beat detector and
the band analyzer over it, and writes a per-frame band table. That table is one
energy value per frame per band. It is cached by content hash, the same way media
is. During the frame loop, a reactive preset is a pure lookup: it reads
`bandTable.energyAt(frame, band)` and applies the transform. No decoding, no
analysis, no live audio happens inside a frame.

This is what keeps reactive renders byte-identical. The same audio file produces
the same band table, and the same band table produces the same pixels on frame 0
and frame 200. Render twice and you get identical frames.

## Captions

`Video.captions` burns a caption track over every scene. Read subtitles from an
SRT file:

<!-- code-excerpt "example/lib/lessons/10_audio_and_captions.dart (captions)" -->
```dart
captions: const Captions.fromSrt(_captions, style: _captionStyle),
```

Three constructors build a track:

<!-- code-excerpt "example/lib/snippets/phase_10_snippets.dart (caption-constructors)" -->
```dart
Captions.fromSrt(path), // parse a SubRip .srt file
Captions.fromVtt(path), // parse a WebVTT .vtt file
Captions.words(cues), // inline, per-word timed cues
```

`fromSrt` and `fromVtt` read and parse the file once before frame 0, the same
pre-pass that resolves media. `words` needs no file: you pass `CaptionWord` cues
with their own `at` times. Lesson 08 narrates its scenes word by word this way:

<!-- code-excerpt "example/lib/lessons/08_code_doc_intro.dart (captions)" -->
```dart
captions: Captions.words(
  const [
    CaptionWord('Type', at: Time.seconds(2.4)),
    CaptionWord('it', at: Time.seconds(3)),
    CaptionWord('out,', at: Time.seconds(3.4)),
    CaptionWord('then', at: Time.seconds(4.2)),
    CaptionWord('run', at: Time.seconds(6.4)),
    CaptionWord('it.', at: Time.seconds(7)),
  ],
  style: const CaptionStyle.tikTok(),
),
```

### Styles

`CaptionStyle` sets the look. Three presets ship:

<!-- code-excerpt "example/lib/snippets/phase_10_snippets.dart (caption-styles)" -->
```dart
CaptionStyle.subtitle(), // a plain, readable lower-third band
CaptionStyle.tikTok(), // bold words that pop in one at a time
CaptionStyle.karaoke(), // a line that highlights each word as it lands
```

The word-pop in `tikTok` reuses the same stagger and reveal you use elsewhere, so
the words enter on their own cues. The `karaoke` style fills each word's color as
its timestamp arrives.

### Positions

`CaptionPosition` sets where the track sits:

<!-- code-excerpt "example/lib/snippets/phase_10_snippets.dart (caption-positions)" -->
```dart
CaptionPosition.bottomThird(), // the default subtitle band
CaptionPosition.topThird(), // above the action
CaptionPosition.center(), // mid-screen
CaptionPosition.custom(Alignment.bottomCenter, safeArea: 96), // any alignment, with an inset
```

Pass `position:` to any caption constructor alongside `style:`.

## Annotations

Annotations draw on top of a scene to point, frame, and label. They are plain
widgets, so `.animate()` adds an outer reveal. An arrow draws on toward a point:

<!-- code-excerpt "example/lib/lessons/07_charts.dart (arrow)" -->
```dart
Positioned.fill(
  child: Arrow.to(
    from: const Offset(720, 200),
    to: const Offset(910, 300),
    drawIn: 500.ms,
  ),
),
```

That draws a shaft from `(720, 200)` to `(910, 300)` over 0.5 seconds, with a head
at the end. A spotlight dims the scene and opens a clear hole over a region:

<!-- code-excerpt "example/lib/lessons/07_charts.dart (spotlight)" -->
```dart
Spotlight.on(
  region: const Rect.fromLTWH(780, 240, 240, 240),
  reveal: 500.ms,
  child: Padding(
    padding: const EdgeInsets.fromLTRB(64, 120, 64, 96),
    child: _themed(
      Chart.line(data: _signups, drawIn: 1500.ms).animate([Animation.fadeIn()]),
    ),
  ),
),
```

The hole grows over the `reveal` window, so the eye lands on the surge. The
annotation family:

- `Shape` draws a line, rectangle, circle, or path.
- `Arrow` draws a shaft with a head toward a point.
- `Connector` joins two explicit points.
- `Spotlight` dims the scene and opens a hole over a region.
- `Callout` points an arrow at a target and labels it.
- `LowerThird` slides a name and title in along the bottom.
- `TitleCard` centers a title and subtitle and reveals them.

A title card opens lesson 08:

<!-- code-excerpt "example/lib/lessons/08_code_doc_intro.dart (title)" -->
```dart
TitleCard(
  title: 'Code, on screen',
  subtitle: 'typed, highlighted, focused',
  reveal: Time.seconds(0.6),
),
```

`Shape`, `Arrow`, and `Connector` draw on with `.animate()`. `Spotlight` grows its
hole over `reveal`. `LowerThird` and `TitleCard` slide and fade in over their own
windows. All of them read colors from `context.fluvie`, so they match your theme.

`Connector` and `Spotlight` take explicit positions in this version. Anchoring
them to another element's rectangle is forthcoming.

## What reacts today, and what is forthcoming

Beat-reactive motion works now, with one scope dependency. `Animation.pulse(on:)`,
`Animation.scaleY(on:)`, and `Bars` all read the precomputed band table and drive
a transform per frame. Like media (which reads an `ImageResolverScope`), reactive
motion needs the render shell's reactive pre-pass and a mounted `ReactiveScope` to
read from. The example and render paths mount it for you. If you build your own
capture shell, mount it yourself. That is the surface to reach for when you want
the picture to move with the music.

Beat-synced timing is a separate idea, and it is not wired into the render path in
this version. `Trigger.beat(every:)` would cut or fire an animation on the beat
grid rather than scale a transform with band energy. The beat grid is detected in
the pre-pass, but the trigger that reads it does not drive the render yet. Reach
for the reactive presets above for motion that follows the music today, and treat
beat-synced cuts as forthcoming.

## Where to next

- [Timing and triggers](timing-and-triggers.md): the trigger vocabulary the
  reactive presets and `Audio.sfx` placement sit beside.
- [Charts and data](charts-and-data.md): the data story the arrow and spotlight
  annotate.
- [Determinism and caching](../advanced/determinism-and-caching.md): why the band
  table is analysed once and the frames stay byte-identical.
```