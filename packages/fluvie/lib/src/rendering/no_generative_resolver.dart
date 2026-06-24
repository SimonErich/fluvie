import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/contracts/generative_resolver.dart';
import 'package:fluvie/src/core/errors/fluvie_generative_exception.dart';
import 'package:fluvie/src/core/media/generative_source.dart';
import 'package:fluvie/src/core/media/media_source.dart';

/// The generation-less [GenerativeResolver]: valid only for compositions that
/// declare no AI-generated media.
///
/// [generateAll] over an empty set succeeds (there is nothing to do); any actual
/// [GenerativeSource] is a typed [FluvieGenerativeException] naming the install
/// fix. This is the library default wired as the `generativeResolverProvider`;
/// the real resolver lives in `fluvie_ai` and overrides the provider.
///
/// `fluvie_ai` and its resolver are named in prose, not as doc links, because
/// they live in a package above `fluvie`.
final class NoGenerativeResolver implements GenerativeResolver {
  /// Creates the resolver; it is stateless and const.
  const NoGenerativeResolver();

  static const String _install =
      'Add package:fluvie_ai and install its generative resolver '
      '(fluvieGenerativeResolver(...), which reads provider API keys from the '
      'environment or an explicit GenerativeConfig) to render Generative* media.';

  @override
  Future<void> generateAll(
    Iterable<GenerativeSource> sources, {
    void Function(GenerativeProgress progress)? onProgress,
  }) async {
    if (sources.isNotEmpty) {
      throw FluvieGenerativeException(
        'No generative backend is installed (got ${sources.length} source(s), '
        'first: "${sources.first}"). $_install',
      );
    }
  }

  @override
  MediaSource mediaFor(GenerativeSource source) =>
      throw FluvieGenerativeException('No generative backend produced "$source". $_install');

  @override
  AudioSource audioFor(GenerativeSource source) =>
      throw FluvieGenerativeException('No generative backend produced "$source". $_install');

  @override
  GeneratedAssetMeta metaFor(GenerativeSource source) =>
      throw FluvieGenerativeException('No generative backend produced "$source". $_install');
}
