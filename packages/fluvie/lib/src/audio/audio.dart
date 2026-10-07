import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/audio/audio_automation.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:meta/meta.dart';

/// One audio track on a `Video` or `Scene`: background music or a
/// one-shot sound effect.
///
/// A declared track is staged into the encoder's audio mix by default, so the
/// rendered file carries sound. Every track is materialized before the frame
/// loop and combined with `amix`, so multiple tracks layer and mix into one
/// output stream. A beat-tagged music track (see [track]) is analysed before
/// frame 0 into a beat grid that `Trigger.beat(track: ...)` resolves against.
@immutable
final class Audio {
  /// A music bed playing for the lifetime of its owner.
  ///
  /// [volume] is a linear gain (1 = as authored), [fadeIn]/[fadeOut] ramp the
  /// ends, [loop] repeats the file to fill the owner's duration, [trim] plays
  /// only that range of the file, and [track] names this track so
  /// `Trigger.beat(track: ...)` can resolve against its analysed beat grid.
  const Audio.music(
    String source, {
    this.volume = 1,
    this.automation = const AudioAutomation(),
    this.ownerStartFrame = 0,
    this.ownerDurationFrames,
    this.fadeIn,
    this.fadeOut,
    this.loop = false,
    this.trim,
    this.track,
    this.at,
  }) : _source = source,
       _typedSource = null,
       _sfx = false;

  /// A music bed over an already-typed [AudioSource] — the same fields as
  /// [Audio.music], skipping the string classification.
  ///
  /// This is how audio that has no path-shaped string reaches the mix: an
  /// [AudioSource.memory] (imported bytes that never touched disk) flows
  /// through here to the encoder, which materializes the bytes itself.
  const Audio.musicSource(
    AudioSource source, {
    this.volume = 1,
    this.automation = const AudioAutomation(),
    this.ownerStartFrame = 0,
    this.ownerDurationFrames,
    this.fadeIn,
    this.fadeOut,
    this.loop = false,
    this.trim,
    this.track,
    this.at,
  }) : _typedSource = source,
       _source = null,
       _sfx = false;

  /// A one-shot sound effect fired [at] a trigger, at [volume].
  const Audio.sfx(
    String source, {
    this.at,
    this.volume = 1,
    this.automation = const AudioAutomation(),
    this.ownerStartFrame = 0,
    this.ownerDurationFrames,
  }) : _source = source,
       _typedSource = null,
       fadeIn = null,
       fadeOut = null,
       loop = false,
       trim = null,
       track = null,
       _sfx = true;

  /// A one-shot sound effect over an already-typed [AudioSource] — the same
  /// fields as [Audio.sfx], skipping the string classification (see
  /// [Audio.musicSource]).
  const Audio.sfxSource(
    AudioSource source, {
    this.at,
    this.volume = 1,
    this.automation = const AudioAutomation(),
    this.ownerStartFrame = 0,
    this.ownerDurationFrames,
  }) : _typedSource = source,
       _source = null,
       fadeIn = null,
       fadeOut = null,
       loop = false,
       trim = null,
       track = null,
       _sfx = true;

  Audio._window(Audio original, this.ownerStartFrame, this.ownerDurationFrames)
    : _source = original._source,
      _typedSource = original._typedSource,
      volume = original.volume,
      automation = original.automation,
      fadeIn = original.fadeIn,
      fadeOut = original.fadeOut,
      loop = original.loop,
      trim = original.trim,
      track = original.track,
      at = original.at,
      _sfx = original._sfx;

  /// Associates a collected scene track with its composition window.
  Audio inWindow(int startFrame, int durationFrames) =>
      Audio._window(this, startFrame, durationFrames);

  /// Composition start of the owning scene, or zero for a video track.
  final int ownerStartFrame;

  /// Owning scene duration, or null for the full video window.
  final int? ownerDurationFrames;

  final String? _source;

  final AudioSource? _typedSource;

  /// Where the audio comes from: an asset path, file path, or URL.
  ///
  /// A typed construction ([Audio.musicSource]/[Audio.sfxSource]) reads back
  /// its source's string form; a memory source, which has no authored string,
  /// reads as the stable `memory:<cacheKey>` label (diagnostics only — the
  /// encoder consumes [audioSource], never this label).
  String get source => _source ?? _sourceString(_typedSource!);

  /// Linear gain applied to the track; `1` plays the file as authored.
  final double volume;

  /// Authored volume envelope, relative to this track's audible window.
  final AudioAutomation automation;

  /// How long the track ramps in from silence; `null` starts at full volume.
  final Time? fadeIn;

  /// How long the track ramps out to silence; `null` stops at full volume.
  final Time? fadeOut;

  /// Whether a music bed repeats to fill its owner's duration.
  final bool loop;

  /// The range of the source file to play; `null` plays the whole file.
  final TimeRange? trim;

  /// Names this track's timeline and its analysed beat grid so triggers can
  /// reference it; `null` leaves the track unnamed.
  final Anchor? track;

  /// When playback begins relative to its owner; null starts with the owner.
  final Trigger? at;

  final bool _sfx;

  /// Whether this track is a one-shot [Audio.sfx] rather than a music bed.
  bool get isSfx => _sfx;

  /// This track's typed, validated [AudioSource].
  ///
  /// A typed construction returns its source verbatim; a string construction
  /// classifies [source] by shape:
  ///
  /// - an `http`/`https` URL becomes an [AudioSource.network],
  /// - a path starting with `/` becomes an [AudioSource.file],
  /// - anything else becomes a bundled [AudioSource.asset].
  ///
  /// Throws a [FluvieRenderException] naming the track when [source] is empty
  /// or a network URL has no host — the encoder must never be handed a blank or
  /// hostless `-i`.
  AudioSource get audioSource =>
      _typedSource ??
      audioSourceFromString(_source!, context: track == null ? null : "on track '$track'");

  @override
  String toString() =>
      _sfx ? 'Audio.sfx($source, at: $at, volume: $volume)' : 'Audio.music($source)';
}

/// The string form of a typed [AudioSource], for [Audio.source] reads: the
/// asset key, file path, or URL as authored, or `memory:<cacheKey>` for a
/// memory source (which has no authored string).
String _sourceString(AudioSource source) => switch (source) {
  AssetAudioSource(:final name) => name,
  FileAudioSource(:final path) => path,
  NetworkAudioSource(:final url) => url.toString(),
  MemoryAudioSource() => 'memory:${source.cacheKey}',
};
