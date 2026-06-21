import 'dart:typed_data';

import 'package:fluvie/src/audio/encoding/audio_mix_plan.dart';
import 'package:fluvie/src/audio/encoding/audio_track_node.dart';
import 'package:fluvie/src/audio/encoding/resolved_audio_track.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/rendering/io/render_sandbox.dart';

/// Loads the bytes of an audio [source] string (an asset key, file path, or URL).
///
/// The encoder-neutral seam each on-device backend supplies: the in-browser
/// renderer fetches assets and network audio, a desktop render reads the
/// pre-materialized file. Staging never touches the file system itself.
typedef AudioByteLoader = Future<Uint8List> Function(String source);

/// Stages every resolved audio [tracks] into [sandbox] and builds the encoder
/// [AudioMixPlan], without touching the file system.
///
/// Each track's bytes (fetched through [loadBytes]) are written under the bare
/// name `audio_<i>_<cacheKey>` the encoder `-i`s, then turned into one
/// [AudioTrackNode] via [AudioTrackNode.fromResolved] (so delay, trim, gain,
/// fade, and loop match every other backend). The cache key comes from
/// [audioSourceFromString], so an in-browser render and a desktop render name the
/// same track identically and the encode args stay byte-identical. [masterVolume]
/// scales the final mix. An empty list stages nothing and returns an empty plan,
/// so the encoder's `-an` path is unchanged.
Future<AudioMixPlan> stageResolvedAudioToSandbox({
  required List<ResolvedAudioTrack> tracks,
  required RenderSandbox sandbox,
  required AudioByteLoader loadBytes,
  double masterVolume = 1,
}) async {
  final nodes = <AudioTrackNode>[];
  for (var i = 0; i < tracks.length; i++) {
    final track = tracks[i];
    final name = 'audio_${i}_${audioSourceFromString(track.source).cacheKey}';
    await sandbox.writeBytes(name, await loadBytes(track.source));
    nodes.add(AudioTrackNode.fromResolved(track, name: name));
  }
  return buildAudioMixPlan(nodes, masterVolume: masterVolume);
}
