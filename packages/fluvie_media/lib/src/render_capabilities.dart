/// Supported render choices for one backend, shared by preflight and docs.
///
/// Profiles describe library support. Codec availability, browser isolation and
/// device hardware still need the environment checks in [notes].
final class RenderCapabilities {
  /// Creates a custom backend profile. Collections are copied and immutable.
  RenderCapabilities({
    required this.backend,
    required Set<String> exportModes,
    required Set<String> videoCodecs,
    required Set<String> pixelFormats,
    required this.audio,
    required this.snapshots,
    required this.exactClipTiming,
    required this.targetBitRate,
    required this.crf,
    required this.presets,
    List<String> evidence = const [],
    List<String> notes = const [],
  }) : exportModes = Set.unmodifiable(exportModes),
       videoCodecs = Set.unmodifiable(videoCodecs),
       pixelFormats = Set.unmodifiable(pixelFormats),
       evidence = List.unmodifiable(evidence),
       notes = List.unmodifiable(notes);

  /// Stable backend name used in diagnostics and the versioned registry.
  final String backend;

  /// Supported `ExportMode` names.
  final Set<String> exportModes;

  /// Supported `ExportCodec` names for MP4 output.
  final Set<String> videoCodecs;

  /// Supported `ExportPixelFormat` names for MP4 output.
  final Set<String> pixelFormats;

  /// Whether the backend can mix authored and embedded clip audio.
  final bool audio;

  /// Whether the adapter owns in-process snapshot capture.
  final bool snapshots;

  /// Whether the default decoder exposes presentation timestamps.
  final bool exactClipTiming;

  /// Whether explicit target video bitrate is supported.
  final bool targetBitRate;

  /// Whether explicit constant rate factor is supported.
  final bool crf;

  /// Whether software encoder presets are supported.
  final bool presets;

  /// Repository-relative regression suites establishing this profile.
  final List<String> evidence;

  /// Environmental requirements and limits beyond the supported choices.
  final List<String> notes;

  /// Whether [mode] is a supported export mode name.
  bool supportsExport(String mode) => exportModes.contains(mode);

  /// Machine-readable profile, with sorted choice lists for stable output.
  Map<String, Object?> toJson() => {
    'backend': backend,
    'exportModes': exportModes.toList()..sort(),
    'videoCodecs': videoCodecs.toList()..sort(),
    'pixelFormats': pixelFormats.toList()..sort(),
    'audio': audio,
    'snapshots': snapshots,
    'exactClipTiming': exactClipTiming,
    'targetBitRate': targetBitRate,
    'crf': crf,
    'presets': presets,
    'evidence': evidence,
    'notes': notes,
  };

  /// FFmpeg desktop adapter support.
  static final desktop = RenderCapabilities(
    backend: 'desktop',
    exportModes: {'mp4', 'gif', 'imageSequence', 'transparent'},
    videoCodecs: {'h264', 'h265'},
    pixelFormats: {'yuv420p', 'yuv420p10le', 'yuv444p'},
    audio: true,
    snapshots: true,
    exactClipTiming: true,
    targetBitRate: true,
    crf: true,
    presets: true,
    evidence: [
      'packages/fluvie/test/rendering/desktop_video_renderer_test.dart',
      'packages/fluvie_media/test/frame_session_integration_test.dart',
      'packages/fluvie/test/rendering/encoding/video_probe_service_test.dart',
      'packages/fluvie/test/rendering/render_to_sandbox_test.dart',
    ],
    notes: [
      'Requires a Flutter capture host and a paired FFmpeg/ffprobe toolchain.',
      'In-process Flutter Snapshot is prepared automatically; external browser snapshots require SnapshotService.',
    ],
  );

  /// Browser capture with the bundled FFmpeg wasm encoder.
  static final browser = RenderCapabilities(
    backend: 'browser',
    exportModes: {'mp4', 'gif', 'imageSequence', 'transparent'},
    videoCodecs: {'h264', 'h265'},
    pixelFormats: {'yuv420p', 'yuv420p10le', 'yuv444p'},
    audio: true,
    snapshots: true,
    exactClipTiming: false,
    targetBitRate: true,
    crf: true,
    presets: true,
    evidence: [
      'packages/fluvie_web_encoder/test/web_video_renderer_test.dart',
      'packages/fluvie/test/rendering/render_to_sandbox_test.dart',
    ],
    notes: [
      'Requires supported browser decoding and FFmpeg wasm.',
      'Threaded wasm requires cross-origin isolation. Encoded bytes remain in browser memory.',
    ],
  );

  /// Android/iOS native hardware encoder support.
  static final mobile = RenderCapabilities(
    backend: 'mobile',
    exportModes: {'mp4'},
    videoCodecs: {'h264', 'h265'},
    pixelFormats: {'yuv420p'},
    audio: true,
    snapshots: true,
    exactClipTiming: false,
    targetBitRate: true,
    crf: false,
    presets: false,
    evidence: [
      'packages/fluvie_mobile_encoder/test/on_device_video_renderer_test.dart',
      'packages/fluvie/test/rendering/render_to_sandbox_test.dart',
    ],
    notes: [
      'Requires an Android/iOS Flutter host and available device codecs.',
      'Hardware decoding and encoding can vary by device.',
    ],
  );

  /// Versioned registry consumed by local documentation and CLI diagnostics.
  static Map<String, Object?> registryJson() => {
    'schemaVersion': 1,
    'backends': [desktop.toJson(), browser.toJson(), mobile.toJson()],
  };
}
