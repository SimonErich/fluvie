import 'package:fluvie/src/audio/audio.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/serialization/anchor_table.dart';
import 'package:fluvie/src/serialization/audio_automation.dart';
import 'package:fluvie/src/serialization/bundle_media.dart';
import 'package:fluvie/src/serialization/codecs/time_codec.dart';
import 'package:fluvie/src/serialization/codecs/trigger_codec.dart';

part 'audio_track_spec_parser.dart';

/// The data form of one [Audio] track on a video or a scene, mirroring the
/// [Audio.music]/[Audio.sfx] constructors field for field.
///
/// A track's `kind` selects the constructor: `music` carries [volume],
/// [fadeIn], [fadeOut], [loop], [trim], and the beat-grid anchor [track];
/// `sfx` carries [at] and [volume]. The parser rejects a music-only key on an
/// sfx track, because the constructors force exactly
/// those fields and a silently dropped key would lie. Placement in time comes
/// from the owner: a video-level track spans the video, a scene-level track
/// starts with its scene.
///
/// Unlike steps and notes, the engine consumes audio: `VideoSpec.build` hands
/// the video-level list to `Video.audio` and `SceneSpec.build` each scene's
/// list to `Scene.audio`, so the existing collector and mix plan read them
/// unchanged, and the digest counts them by the default rule.
final class AudioTrackSpec {
  /// Creates a music-bed track playing for the lifetime of its owner.
  ///
  /// Give exactly one origin: a typed [source], or a bundle-relative [bundle]
  /// value that resolves through `BundleMedia` when [AudioTrackSpec.source]
  /// is read. Throws an [ArgumentError] otherwise.
  AudioTrackSpec.music({
    AudioSource? source,
    this.bundle,
    this.volume = 1,
    this.automation = const AudioAutomation(),
    this.fadeIn,
    this.fadeOut,
    this.loop = false,
    this.trim,
    this.track,
    this.at,
    this.lane,
  }) : _source = _oneOrigin(source, bundle),
       isSfx = false;

  /// Creates a one-shot sound-effect track fired [at] a trigger.
  ///
  /// Give exactly one origin: a typed [source], or a bundle-relative [bundle]
  /// value that resolves through `BundleMedia` when [AudioTrackSpec.source]
  /// is read. Throws an [ArgumentError] otherwise.
  AudioTrackSpec.sfx({
    AudioSource? source,
    this.bundle,
    this.at,
    this.volume = 1,
    this.automation = const AudioAutomation(),
    this.lane,
  }) : _source = _oneOrigin(source, bundle),
       fadeIn = null,
       fadeOut = null,
       loop = false,
       trim = null,
       track = null,
       isSfx = true;

  /// Reads one track from [json], resolving its `track` anchor id and any
  /// `at` trigger through [anchors].
  ///
  /// Throws a [FluvieSpecError] (located under [path]) for an unknown kind, a
  /// malformed or kind-mismatched source, a negative volume, or a music-only key on an sfx track.
  factory AudioTrackSpec.fromJson(
    Map<String, Object?> json,
    AnchorTable anchors, {
    List<String> path = const [],
  }) => _parseAudioTrack(json, anchors, path);

  /// The keys a music track reads; the single source of truth for the
  /// music-track unknown-property check.
  static const Set<String> musicKeys = {
    'kind',
    'source',
    'at',
    'volume',
    'automation',
    'fadeIn',
    'fadeOut',
    'loop',
    'trim',
    'track',
    'lane',
  };

  /// The keys an sfx track reads; the single source of truth for the
  /// sfx-track unknown-property check.
  static const Set<String> sfxKeys = {'kind', 'source', 'at', 'volume', 'automation', 'lane'};

  /// The bundle-relative value (`media/<name>`) this track's audio lives
  /// under inside its `.fluvie` bundle, or null for a typed source. The JSON
  /// form keeps this value, so the digest stays machine-stable; [source]
  /// resolves it through the materialized `BundleMedia` scope.
  final String? bundle;

  final AudioSource? _source;

  /// Where the audio comes from. The engine classifies a track's source
  /// string by shape, so the parser guarantees the declared kind and that
  /// classification agree (see `audioSourceFromString`).
  ///
  /// A [bundle]-backed track resolves here through `BundleMedia`; reading it
  /// with no bundle in scope throws a [FluvieSpecError] naming the missing
  /// bundle context (the ADR's build-time law).
  AudioSource get source => _source ?? BundleMedia.resolveAudio(bundle!, path: const ['source']);

  /// Linear gain applied to the track; `1` plays the file as authored.
  final double volume;

  /// Keyframed volume multipliers relative to the audible window.
  final AudioAutomation automation;

  /// How long a music bed ramps in from silence; null starts at full volume.
  final Time? fadeIn;

  /// How long a music bed ramps out to silence; null stops at full volume.
  final Time? fadeOut;

  /// Whether a music bed repeats to fill its owner's duration.
  final bool loop;

  /// The range of the source file a music bed plays; null plays the whole
  /// file.
  final TimeRange? trim;

  /// The anchor naming this music track's analysed beat grid, so
  /// `Trigger.beat(track: ...)` can reference it; null leaves it unnamed.
  final Anchor? track;

  /// When playback begins relative to its owner; null starts with the owner.
  final Trigger? at;

  /// Whether this track is a one-shot [Audio.sfx] rather than a music bed.
  final bool isSfx;

  /// The timeline row this track is drawn on, or null for none.
  ///
  /// A muted lane silences the track: it is the one lane field that reaches
  /// the render, because a mute the export ignored would be a lie the author
  /// only discovers in the file.
  final String? lane;

  /// The JSON form of this track: only the declared parts, canonically
  /// encoded, with constructor defaults elided.
  Map<String, Object?> toJson() => {
    'kind': isSfx ? 'sfx' : 'music',
    'source': bundle != null ? {'kind': 'bundle', 'value': bundle} : _encodeAudioSource(_source!),
    if (at != null) 'at': encodeTrigger(at!),
    if (volume != 1) 'volume': volume,
    if (!automation.isEmpty) 'automation': encodeAudioAutomation(automation),
    if (fadeIn != null) 'fadeIn': encodeTime(fadeIn!),
    if (fadeOut != null) 'fadeOut': encodeTime(fadeOut!),
    if (loop) 'loop': true,
    if (trim != null) 'trim': {'from': encodeTime(trim!.start), 'to': encodeTime(trim!.end)},
    if (track != null) 'track': _trackId(track!),
    if (lane != null) 'lane': lane,
  };

  /// Builds the real [Audio] constructor call this track mirrors.
  ///
  /// The typed [source] flows through [Audio.musicSource]/[Audio.sfxSource]
  /// verbatim, so a bundle-resolved memory source (web-imported bytes) reaches
  /// the encoder's collect pass with its bytes intact.
  Audio build({double laneGain = 1}) => isSfx
      ? Audio.sfxSource(source, at: at, volume: volume * laneGain, automation: automation)
      : Audio.musicSource(
          source,
          volume: volume * laneGain,
          automation: automation,
          fadeIn: fadeIn,
          fadeOut: fadeOut,
          loop: loop,
          trim: trim,
          track: track,
          at: at,
        );
}

/// Exactly one of [source] and [bundle], or an [ArgumentError].
AudioSource? _oneOrigin(AudioSource? source, String? bundle) {
  if ((source == null) == (bundle == null)) {
    throw ArgumentError('An audio track takes exactly one of "source" and "bundle"');
  }
  return source;
}
