import 'package:fluvie/src/audio/encoding/amix_node.dart';
import 'package:fluvie/src/audio/encoding/audio_track_node.dart';
import 'package:meta/meta.dart';

/// The encoder audio graph for one render: the ordered track
/// nodes and the [AmixNode] that combines them, or no amix when there are no
/// tracks.
///
/// The render path hands the [tracks] (and [amix]) to the arg builder, which
/// emits each track's `-i` and `filterChain`, then the amix's `mixChain`, then
/// `-map [aout]`. A silent composition produces an empty plan and the builder's
/// `-an` path is unchanged.
@immutable
final class AudioMixPlan {
  /// Creates a plan over the ordered [tracks] and their [amix] (`null` when
  /// there are no tracks).
  const AudioMixPlan({required this.tracks, required this.amix});

  /// The per-track nodes, in stable order (the order they were collected).
  final List<AudioTrackNode> tracks;

  /// The mixdown stage, or `null` for a silent (track-less) composition.
  final AmixNode? amix;

  /// Whether this plan has no audio (the builder falls back to `-an`).
  bool get isEmpty => tracks.isEmpty;
}

/// Builds the [AudioMixPlan] for the ordered [tracks], scaling the mix by
/// [masterVolume].
///
/// Pure and deterministic: the same tracks in the same order yield an equal
/// plan, which is what makes the encode arg array byte-identical run to run. An
/// empty track list yields an empty plan with no amix.
AudioMixPlan buildAudioMixPlan(List<AudioTrackNode> tracks, {double masterVolume = 1}) {
  if (tracks.isEmpty) return const AudioMixPlan(tracks: [], amix: null);
  return AudioMixPlan(
    tracks: List.unmodifiable(tracks),
    amix: AmixNode(inputCount: tracks.length, masterVolume: masterVolume),
  );
}
