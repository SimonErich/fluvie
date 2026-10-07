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
/// surface. The barrels share value types. Authoring stays free of pipeline
/// machinery, and this surface assumes you are building or hosting a renderer.
library;

export 'package:fluvie_media/fluvie_media.dart' show MediaTimeline, RenderCapabilities;

export 'src/animation/motion_target.dart' show MotionTarget;
export 'src/animation/runtime/color_lookup_scope.dart' show ColorLookupScope;
export 'src/animation/runtime/shader_loader.dart' show FragmentProgramShaderLoader, ShaderLoader;
export 'src/animation/runtime/warm_shader_scope.dart' show WarmShaderScope;
export 'src/audio/encoding/resolved_audio_track.dart'
    show ResolvedAudioMix, ResolvedAudioTrack, resolveAudioTrack;
export 'src/audio/runtime/ffmpeg_audio_decoder.dart' show FfmpegAudioDecoder;
export 'src/audio/runtime/ffmpeg_pcm_decoder.dart' show FfmpegPcmDecoder;
export 'src/audio/runtime/pcm_decoder.dart' show PcmDecoder;
export 'src/audio/runtime/ranged_pcm_decoder.dart' show RangedPcmDecoder;
export 'src/audio/runtime/shared_pcm_decoder.dart' show SharedPcmDecoder;
export 'src/audio/runtime/spectral_beat_detection_service.dart';
export 'src/audio/runtime/spectral_frequency_analyzer.dart';
export 'src/composition/runtime/clip_plan_collector.dart'
    show ClipAudioPlan, ClipPlan, collectClipPlans;
export 'src/composition/runtime/color_lookup_collector.dart'
    show ColorLookupPlan, collectColorLookups;
export 'src/composition/runtime/media_collector.dart'
    show collectMediaSources, collectSnapshotSources, collectSnapshots;
export 'src/composition/runtime/scene_tree_walk.dart' show declaredChildren;
export 'src/composition/runtime/shader_collector.dart' show collectShaderAssets;
export 'src/core/audio/audio_analysis_window.dart';
export 'src/core/audio/audio_automation.dart';
export 'src/core/audio/audio_time_map.dart' show AudioTimeMap;
export 'src/core/audio/dsp/wav_reader.dart' show PcmAudio, readPcmWav;
export 'src/core/audio/waveform_envelope.dart'
    show WaveformBucket, WaveformEnvelope, reduceToWaveform;
export 'src/core/contracts/audio_window_resolver.dart';
export 'src/core/contracts/beat_detection_service.dart' show BeatDetectionService;
export 'src/core/contracts/clip_timeline_resolver.dart' show ClipTimelineResolver, clipTimelineFor;
export 'src/core/contracts/disposable_resolver.dart' show DisposableResolver;
export 'src/core/contracts/frequency_analyzer.dart' show FrequencyAnalyzer;
export 'src/core/contracts/generative_resolver.dart';
export 'src/core/contracts/media_resolver.dart';
export 'src/core/contracts/ranged_audio_analysis.dart';
export 'src/core/contracts/snapshot_service.dart' show SnapshotService;
export 'src/core/encoder_options.dart' show EncoderPreset, ExportCodec, ExportPixelFormat;
export 'src/core/render_phase.dart';
export 'src/elements/runtime/clip_frame_planner.dart'
    show resolveClipTrimBounds, resolveClipTrimOffsets;
export 'src/elements/runtime/clip_resampler.dart' show resampleClipFrame;
export 'src/elements/runtime/clip_speed_profile.dart' show integrateClipSpeedRamp;
export 'src/media/media_providers_common.dart' show mediaCancellationProvider;
export 'src/media/net/network_allowlist.dart' show NetworkAllowlist;
export 'src/media/render_resolver_scope.dart' show ResolverScope, resolverScope;
export 'src/media/web_clip_decoder.dart' show WebClipDecoder, WebClipTimelineDecoder;
export 'src/rendering/assets/project_asset_bundle.dart' show ProjectAssetBundle, ProjectAssetReader;
export 'src/rendering/assets/render_fonts.dart' show fluvieDefaultFontFamily, loadRenderFonts;
export 'src/rendering/audio_mix_resolution.dart' show resolveAudioMix;
export 'src/rendering/audio_opt_in_gate.dart' show gateOptInAudio;
export 'src/rendering/audio_sandbox_staging.dart' show AudioByteLoader, stageResolvedAudioToSandbox;
export 'src/rendering/capture/frame_capture_service.dart';
export 'src/rendering/capture/raw_frame.dart';
export 'src/rendering/capture/render_manifest.dart';
export 'src/rendering/capture/repaint_boundary_capture_service.dart';
export 'src/rendering/capture_mounted_snapshots.dart';
export 'src/rendering/clip_audio_probe.dart' show probeTrimmedClips;
export 'src/rendering/clip_audio_source.dart' show clipAudioSourceFor;
export 'src/rendering/clip_audio_trim.dart' show resolveClipAudioTrimSeconds;
export 'src/rendering/clip_thumbnails.dart' show clipThumbnails;
export 'src/rendering/collect_composition_media.dart' show compositionVideo;
export 'src/rendering/composition_session.dart' show CompositionSession;
export 'src/rendering/desktop_video_renderer.dart' show DesktopVideoRenderer;
export 'src/rendering/encoding/ffmpeg_frame_extraction_service.dart'
    show frameExtractionServiceProvider;
export 'src/rendering/encoding/ffmpeg_runner.dart' show FfmpegRunner;
export 'src/rendering/encoding/ffmpeg_version.dart' show FfmpegVersion;
export 'src/rendering/encoding/frame_cache.dart';
export 'src/rendering/encoding/frame_extraction_cache_identity.dart'
    show FrameExtractionCacheIdentity;
export 'src/rendering/encoding/frame_extraction_service.dart' show FrameExtractionService;
export 'src/rendering/encoding/frame_extraction_session.dart'
    show FrameExtractionSession, FrameExtractionSessionService;
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
export 'src/rendering/platform/wasm_runtime.dart' show WasmRuntime, WasmRuntimeLifecycle;
export 'src/rendering/platform/wasm_runtime_bindings.dart' show createWasmRuntime;
export 'src/rendering/pre_bake_color_lookups.dart'
    show CubeTextLoader, bundleCubeText, preBakeCompositionColorLookups;
export 'src/rendering/pre_load_shaders.dart' show preLoadCompositionShaders, preLoadShaders;
export 'src/rendering/prepared_composition.dart' show PreparedComposition;
export 'src/rendering/primitives/fade_box.dart';
export 'src/rendering/render_aspect.dart'
    show RenderAspectResult, ShellFramePump, ShellMount, render;
export 'src/rendering/render_cancellation.dart' show RenderCancellation, RenderCancelledException;
export 'src/rendering/render_cleanup.dart' show runGuarded;
export 'src/rendering/render_config.dart';
export 'src/rendering/render_duration.dart' show frameCountFor;
export 'src/rendering/render_host.dart'
    show RenderFactory, RenderHostContext, RenderInvocation, runFluvieRender;
export 'src/rendering/render_options.dart'
    show parseAspect, parseExportFormat, parsePosterTime, parseQuality, writeRenderProgress;
export 'src/rendering/render_progress.dart' show RenderProgress, RenderProgressCallback;
export 'src/rendering/render_service.dart';
export 'src/rendering/render_stage.dart' show runStage;
export 'src/rendering/render_template.dart' show renderTemplate;
export 'src/rendering/render_to_sandbox.dart'
    show AudioMixResolver, FrameEncoder, SandboxFramePump, SandboxMount, renderToSandbox;
export 'src/rendering/render_video.dart'
    show SetViewSize, ShellRunAsync, renderVideo, runAsyncDirectly;
export 'src/rendering/render_worker.dart' show runFluvieWorker;
export 'src/rendering/request_video_renderer.dart' show RequestVideoRenderer;
export 'src/rendering/review_text.dart' show inspectRenderedText;
export 'src/rendering/runtime/timeline_preview_audio.dart'
    show PreviewAudioPlayer, PreviewAudioPlayerFactory, TimelinePreviewAudioController;
export 'src/rendering/video_render_request.dart' show VideoRenderRequest;
export 'src/rendering/video_renderer.dart' show VideoRenderer;
export 'src/timing/placement/window_resolver.dart' show elementScopeFor;
export 'src/timing/time_scope_data.dart' show TimeScopeData;
