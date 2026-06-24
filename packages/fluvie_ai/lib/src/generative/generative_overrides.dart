import 'dart:io';

import 'package:fluvie/fluvie.dart' show GenerativeResolver;
import 'package:fluvie_ai/src/generative/generative_config.dart';
import 'package:fluvie_ai/src/generative/generative_media_resolver.dart';

/// Builds the real [GenerativeResolver] from an explicit [config] or the process
/// environment — the one-line wiring a render needs to produce `Generative*`
/// media.
///
/// Pass it to a render (the `generative:` argument), or install it as the
/// `generativeResolverProvider` override:
///
/// ```dart
/// ProviderContainer(
///   overrides: [generativeResolverProvider.overrideWithValue(fluvieGenerativeResolverFor())],
/// );
/// ```
GenerativeResolver fluvieGenerativeResolverFor({
  GenerativeConfig? config,
  Map<String, String>? env,
}) => GenerativeMediaResolver(
  config: config ?? GenerativeConfig.fromEnv(env ?? Platform.environment),
);
