import 'package:fluvie/src/audio/encoding/audio_filter_graph.dart';
import 'package:fluvie/src/rendering/encoding/audio_graph_nodes.dart';
import 'package:meta/meta.dart';

/// The mixdown stage of the encoder audio graph: combines
/// every per-track pad into one stream and applies the master volume.
///
/// Each `AudioTrackNode` emits a labelled pad; the [AmixNode] consumes all
/// [inputCount] of them through `amix=inputs=N:normalize=0` (normalize off so a
/// track's authored gain is preserved, not auto-attenuated) and a final master
/// `volume`, producing a single output pad the arg builder maps as the audio
/// stream. Like the track node it serializes typed values only, never a shell
/// string.
///
/// `AudioTrackNode` is named in prose, not as a doc link, to avoid an import
/// cycle.
@immutable
final class AmixNode implements FfmpegAudioMix {
  /// Creates a mix over [inputCount] track pads, scaled by [masterVolume].
  const AmixNode({required this.inputCount, this.masterVolume = 1})
    : assert(inputCount >= 1, 'amix needs at least one input');

  /// How many labelled track pads feed the mix.
  final int inputCount;

  /// The linear gain applied to the mixed stream (`1` leaves it untouched).
  final double masterVolume;

  /// The `-filter_complex` chain reading every pad in [labels] and producing
  /// the single [outLabel] pad. The number of [labels] must equal [inputCount].
  @override
  String mixChain({required List<String> labels, required String outLabel}) {
    if (labels.length != inputCount) {
      throw ArgumentError.value(
        labels,
        'labels',
        'must supply exactly $inputCount pad label(s) to match inputCount',
      );
    }
    final inputs = labels.map((label) => '[$label]').join();
    final volume = formatFilterNumber(masterVolume);
    return '${inputs}amix=inputs=$inputCount:normalize=0,volume=$volume[$outLabel]';
  }
}
