import 'package:fluvie/fluvie.dart';

/// One renderable composition the capture harness can mount by key.
///
/// The registry in `composition_registry.dart` maps CLI keys (for example
/// `demo`) to entries. Everything a render needs — geometry, fps, frame count,
/// declared media, audio, captions — is derived from the built [video], so an
/// entry carries only its key and its builder.
final class CompositionEntry {
  /// Creates an entry naming one composition.
  const CompositionEntry({required this.key, required this.video});

  /// The CLI-facing key (`fluvie render <key>`).
  final String key;

  /// Builds the composition.
  ///
  /// Called fresh per render, and by the capture loop's clock, so it must be
  /// deterministic: the same key always builds the same `Video`.
  final Video Function() video;
}
