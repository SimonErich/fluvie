import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/contracts/generative_resolver.dart';
import 'package:fluvie/src/core/errors/fluvie_generative_exception.dart';
import 'package:fluvie/src/core/media/generative_source.dart';
import 'package:fluvie/src/core/media/media_source.dart';

/// Canned [GenerativeResolver] for tests: records what [generateAll] was asked
/// to produce and serves a fixed `GenerativeSource -> MediaSource/AudioSource`
/// map afterwards, enforcing that reads only happen after [generateAll].
final class FakeGenerativeResolver implements GenerativeResolver {
  /// Creates a resolver serving [media], [audio], and [meta] for produced
  /// sources.
  FakeGenerativeResolver({
    Map<GenerativeSource, MediaSource> media = const {},
    Map<GenerativeSource, AudioSource> audio = const {},
    Map<GenerativeSource, GeneratedAssetMeta> meta = const {},
  }) : _media = Map.of(media),
       _audio = Map.of(audio),
       _meta = Map.of(meta);

  final Map<GenerativeSource, MediaSource> _media;
  final Map<GenerativeSource, AudioSource> _audio;
  final Map<GenerativeSource, GeneratedAssetMeta> _meta;

  /// Every source passed to [generateAll], in call order.
  final List<GenerativeSource> generated = [];

  @override
  Future<void> generateAll(
    Iterable<GenerativeSource> sources, {
    void Function(GenerativeProgress progress)? onProgress,
  }) async {
    final list = sources.toList();
    generated.addAll(list);
    for (var i = 0; i < list.length; i++) {
      onProgress?.call((
        index: i,
        total: list.length,
        providerId: list[i].providerId,
        stage: 'cached',
      ));
    }
  }

  @override
  MediaSource mediaFor(GenerativeSource source) =>
      _media[source] ?? (throw FluvieGenerativeException('no canned media for "$source"'));

  @override
  AudioSource audioFor(GenerativeSource source) =>
      _audio[source] ?? (throw FluvieGenerativeException('no canned audio for "$source"'));

  @override
  GeneratedAssetMeta metaFor(GenerativeSource source) =>
      _meta[source] ?? (throw FluvieGenerativeException('no canned meta for "$source"'));
}
