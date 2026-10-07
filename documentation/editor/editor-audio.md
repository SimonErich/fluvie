# Audio editing

The Audio workspace groups lanes, meter estimates, per-track volume automation,
and ducking. All edits use the document's command history, so undo restores the
complete previous envelope. Lane mute and gain affect export. **Solo monitor**
is session state and never enters a saved document or an exported mix.

## Automation

Audio uses the same `values`, `positions` and `easings` grammar as effects.
Positions are measured from the audible start of a track, or from a clip's own
window. The gain multiplier is clamped to 0–1 and multiplies the authored track
volume and lane gain. A single constant is represented by a number.

```json
{
  "kind": "music",
  "source": {"kind": "asset", "value": "audio/bed.wav"},
  "automation": {
    "volume": {
      "values": [1.0, 0.25, 0.25, 1.0],
      "positions": ["0f", "30f", "90f", "120f"]
    }
  }
}
```

The same `automation` property on a Clip controls its embedded audio. In Dart:

<!-- code-excerpt "examples/gallery/lib/snippets/spec_serialization_snippets.dart (audio-automation)" -->
```dart
final music = Audio.music(
  'audio/bed.wav',
  automation: AudioAutomation(
    values: const [1, 0.25, 1],
    positions: [0.frames, 1.seconds, 4.seconds],
    easings: const [Ease.smooth, Ease.linear],
  ),
);
```

Add a volume stop at the playhead, then edit its gain, frame and outgoing easing
in the Audio inspector. Times stay ordered. Removing the last stop clears the
envelope; changing a value preserves the other stops and their easing.

FFmpeg receives one typed, deterministic `volume` expression with `eval=frame`.
No authored text is inserted into the graph. Linear segments remain linear;
nonlinear easings resolve to composition-frame samples and the same samples
are handed to custom and mobile encoders. Empty automation preserves the
previous static filter string exactly. Mix order always remains document
order, regardless of lane order.

## Lanes and meters

Gain is edited in dB and saved as linear amplitude (`0 dB = 1`, approximately
`-6.02 dB = 0.5`). Mute removes assigned tracks from the render mix. Scene audio
starts and ends with its scene, including overlapping transitions. Automation,
trim, loops, rate and fades are reflected in the meter calculation.

Meters use cached decoded waveform envelopes, so they work without a live audio
device. Individual peak and RMS values derive from source buckets. Combined
peak is a conservative ceiling and combined RMS assumes uncorrelated sources:
waveform summaries do not retain sample phase. The workspace labels them as
estimates and indicates values above full scale as `CLIP`.

## Ducking

Select a trigger lane and target lane. Set attenuation, attack, hold and release,
then choose **Apply ducking**. Trigger presence writes ordinary automation onto
each target track as one undo step. Overlapping trigger windows do not allow
the target to rise between them. Ducking replaces the target's prior volume
automation; undo restores it exactly. Export uses the written envelope, without
any special runtime ducking process.

## Verification

Maintained tests cover absent-envelope graph identity, single/multiple stops,
ordering validation, clamping, shared easing resolution, round-trip digest,
scene timing, lane mute/gain/order, monitoring-only solo, meter estimates,
ducking overlap/shape/undo, and an actual FFmpeg PCM encode whose measured
amplitude falls to the authored duck level and recovers afterward. Android and
iOS use the same resolved sample list; native device validation requires their
respective SDKs and devices.

## Placement and program audition

Both music and sound effects accept `at`, relative to their scene or the video.
A placed music track retains its source trim, looping and fades. A trimmed bed
placed at 3 seconds with a 2–5 second source trim plays from 3 to 6 seconds;
its fade-out ends at 6 seconds, subject to its owner's end.

Embedded clip audio appears alongside declared tracks in the Audio workspace.
Its lane gain, automation and ducking use the actual built clip window, including
transition crossfades. Probed source metadata resolves trimmed clips at their
source frame rate. An unprobed trimmed clip is marked unavailable for audition
until metadata is loaded, rather than played from an invented source range.

Program audition mixes bounded chunks of cached PCM. Solo is applied only to
those chunks and meter estimates. Timeline waveforms cover absolute composition
time, with silence before placement and after each audible window; they reflect
trim, playback rate, speed ramps and automation. Waveform columns are bounded
samples of cached summaries, rather than an exact recording of the final mix.

Speed ramps carry an integrated output-to-source clock to every encoder. FFmpeg
uses persistent `atempo` stages with source-time commands, followed by volume,
fades and delay. Its pitch-preserving processing has normal audio-block timing
precision. The pure audition mixer and Android use sample resampling, so pitch
changes with playback speed; iOS scales source segments through AVFoundation.
Native-device audio quality and platform codec availability need verification
on the target device.

Program and Source Listen audition use a mono downmix; export channels remain
independent. Decoded PCM is cached in a 128 MiB LRU, source waveforms use 2048
buckets, and audition chunks are limited to 30 seconds. Desktop audition requires
ffmpeg and ffplay. Browser audition uses Web Audio with imported bytes or
CORS-enabled sources. Load/playback errors remain visible with a retry action.

## Cutting and removing music

An explicitly placed, non-looping music track with exact source trim supports
razor, lift, extract and ripple edits. Razor keeps both source ranges adjacent;
extract closes the removed time while preserving each remaining source range.
Scene-owned tracks retain their scene-relative clock. Curved automation and
fades are cropped into ordinary volume points, preserving gain at every
composition frame instead of restarting the fade on each new piece. Embedded
clip audio receives the same envelope slicing when its picture is razored.

Tracks with trigger placement, named beat timelines, looping, or unknown trim
report the required change before an exact structural edit. Locked lanes refuse
the whole edit. Each structural action, including edits to multiple audio and
picture items, is one undoable command.
