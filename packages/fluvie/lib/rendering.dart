/// The pipeline surface behind Fluvie's renderers: capture services, render
/// sandboxes, encoding seams, media-resolver contracts, and the renderer
/// entry points they compose.
///
/// Import it where frames are produced — a render harness, an encoder
/// backend, a server — never inside a composition:
///
/// ```dart
/// import 'package:fluvie/rendering.dart';
/// ```
///
/// Compositions import only `package:fluvie/fluvie.dart`, the authoring
/// surface. The two barrels are disjoint: authoring stays free of pipeline
/// machinery, and this surface assumes you are building or hosting a
/// renderer.
library;

export 'src/audio/encoding/resolved_audio_track.dart' show ResolvedAudioMix, ResolvedAudioTrack;
export 'src/composition/runtime/media_collector.dart'
    show collectMediaSources, collectSnapshotSources, collectSnapshots;
export 'src/core/contracts/beat_detection_service.dart' show BeatDetectionService;
export 'src/core/contracts/disposable_resolver.dart' show DisposableResolver;
export 'src/core/contracts/frequency_analyzer.dart' show FrequencyAnalyzer;
export 'src/core/contracts/generative_resolver.dart';
export 'src/core/contracts/media_resolver.dart';
export 'src/core/contracts/snapshot_service.dart' show SnapshotService;
export 'src/core/render_phase.dart';
export 'src/media/net/network_allowlist.dart' show NetworkAllowlist;
export 'src/media/render_resolver_scope.dart' show ResolverScope, resolverScope;
export 'src/media/web_clip_decoder.dart' show WebClipDecoder;
export 'src/rendering/audio_mix_resolution.dart' show resolveAudioMix;
export 'src/rendering/audio_opt_in_gate.dart' show gateOptInAudio;
export 'src/rendering/audio_sandbox_staging.dart' show AudioByteLoader, stageResolvedAudioToSandbox;
export 'src/rendering/capture/frame_capture_service.dart';
export 'src/rendering/capture/raw_frame.dart';
export 'src/rendering/capture/render_manifest.dart';
export 'src/rendering/capture/repaint_boundary_capture_service.dart';
export 'src/rendering/desktop_video_renderer.dart' show DesktopVideoRenderer;
export 'src/rendering/encoding/ffmpeg_frame_extraction_service.dart'
    show frameExtractionServiceProvider;
export 'src/rendering/encoding/ffmpeg_runner.dart' show FfmpegRunner;
export 'src/rendering/encoding/ffmpeg_version.dart' show FfmpegVersion;
export 'src/rendering/encoding/frame_cache.dart';
export 'src/rendering/encoding/frame_extraction_service.dart' show FrameExtractionService;
export 'src/rendering/encoding/video_probe_service.dart'
    show VideoProbeResult, VideoProbeService, videoProbeServiceProvider;
export 'src/rendering/generative_resolver_provider.dart';
export 'src/rendering/io/file_render_sandbox.dart' show FileRenderSandbox;
export 'src/rendering/io/memory_render_sandbox.dart' show MemoryRenderSandbox;
export 'src/rendering/io/render_sandbox.dart';
export 'src/rendering/no_generative_resolver.dart';
export 'src/rendering/no_media_resolver.dart';
export 'src/rendering/platform/ffmpeg_runner_registry.dart'
    show FfmpegRunnerRegistry, ffmpegRunnerProvider;
export 'src/rendering/platform/wasm_runtime.dart' show WasmRuntime;
export 'src/rendering/platform/wasm_runtime_bindings.dart' show createWasmRuntime;
export 'src/rendering/primitives/fade_box.dart';
export 'src/rendering/render_aspect.dart'
    show RenderAspectResult, ShellFramePump, ShellMount, render;
export 'src/rendering/render_cleanup.dart' show runGuarded;
export 'src/rendering/render_config.dart';
export 'src/rendering/render_duration.dart' show frameCountFor;
export 'src/rendering/render_progress.dart' show RenderProgress, RenderProgressCallback;
export 'src/rendering/render_service.dart';
export 'src/rendering/render_stage.dart' show runStage;
export 'src/rendering/render_template.dart' show renderTemplate;
export 'src/rendering/render_to_sandbox.dart'
    show FrameEncoder, SandboxFramePump, SandboxMount, renderToSandbox;
export 'src/rendering/video_renderer.dart' show VideoRenderer;
