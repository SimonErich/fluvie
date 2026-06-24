/// Native entrypoint for AI-generated media in Fluvie.
///
/// Import this alongside `package:fluvie_ai/fluvie_ai.dart` on a server, the CLI,
/// or a device to install the generative resolver that produces `GenerativeImage`
/// / `GenerativeVideo` / `GenerativeMusic` (and friends) before a render:
///
/// ```dart
/// import 'package:fluvie_ai/generative.dart';
///
/// final resolver = fluvieGenerativeResolverFor(); // reads provider keys from env
/// ```
///
/// It uses `dart:io` (the on-disk asset cache), so it is kept out of the
/// web-safe `fluvie_ai` barrel.
library;

export 'src/generative/generative_cache.dart' show GenerativeCache, defaultGenerativeCacheDir;
export 'src/generative/generative_config.dart';
export 'src/generative/generative_media_resolver.dart' show GenerateFn, GenerativeMediaResolver;
export 'src/generative/generative_overrides.dart' show fluvieGenerativeResolverFor;
export 'src/generative/generative_providers.dart' show generateFor, providerIdFor;
