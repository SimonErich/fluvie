/// Optional persistent-cache identity advertised by a frame extractor.
///
/// The identity covers implementation, build and pixel-affecting configuration.
/// Source bytes, output geometry and selected decoder are keyed separately.
/// Change the identity whenever the same inputs could produce different pixels.
/// Extractors without this contract remain usable but are not cached across runs.
abstract interface class FrameExtractionCacheIdentity {
  /// Stable backend identity, or null when persistent reuse cannot be justified.
  /// Resolve expensive build metadata once; this is not a per-frame operation.
  Future<String?> get cacheIdentity;
}
