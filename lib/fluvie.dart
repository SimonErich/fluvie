/// Fluvie - A Flutter package for programmatic video generation.
///
/// Fluvie allows you to create videos using Flutter widgets and export them
/// using FFmpeg. It provides a declarative API for composing video content
/// with precise frame-level control.
///
/// ## Which Import to Use
///
/// Fluvie offers two entry points depending on your needs:
///
/// ### `package:fluvie/fluvie.dart` (this library)
///
/// Full API access including:
/// - Low-level composition widgets ([VideoComposition], [TimeConsumer], [Layer])
/// - Encoding services ([VideoEncoderService], [FrameSequencer])
/// - Render pipeline ([RenderService], [RenderConfig])
/// - FFmpeg integration and frame extraction
///
/// Use this when you need fine-grained control over rendering and encoding.
///
/// ### `package:fluvie/declarative.dart`
///
/// High-level declarative API including:
/// - Scene-based composition ([Video], [Scene])
/// - V-prefix layout widgets ([VCenter], [VRow], [VColumn], [VStack])
/// - Animated text ([AnimatedText], [TypewriterText])
/// - Property animations ([AnimatedProp], [PropAnimation])
/// - Background effects ([Background.gradient], [Background.noise])
///
/// Use this for most video projects where you want the simplest API.
///
/// ## Quick Start (Declarative API)
///
/// ```dart
/// import 'package:fluvie/declarative.dart';
///
/// Video(
///   fps: 30,
///   width: 1080,
///   height: 1920,
///   scenes: [
///     Scene(
///       durationInFrames: 120,
///       background: Background.solid(Colors.black),
///       children: [
///         VCenter(
///           child: AnimatedText.slideUpFade('Hello World'),
///         ),
///       ],
///     ),
///   ],
/// )
/// ```
///
/// ## Quick Start (Low-Level API)
///
/// ```dart
/// import 'package:fluvie/fluvie.dart';
///
/// final composition = VideoComposition(
///   fps: 30,
///   durationInFrames: 150, // 5 seconds
///   child: TimeConsumer(
///     builder: (context, frame, progress) {
///       return Center(
///         child: Opacity(
///           opacity: progress,
///           child: Text('Hello World!'),
///         ),
///       );
///     },
///   ),
/// );
/// ```
///
/// ## Key Concepts
///
/// - **Frame-based timing**: All timing uses frame numbers, not duration.
///   At 30fps, 90 frames = 3 seconds.
/// - **Widget-based**: Videos are composed using Flutter widgets.
/// - **Declarative**: Describe what you want, not how to render it.
/// - **FFmpeg encoding**: Final output uses FFmpeg for encoding.
library;

import 'fluvie_platform_interface.dart';

// Presentation layer - Core widgets
export 'src/presentation/video_composition.dart';
export 'src/presentation/sequence.dart';
export 'src/presentation/time_consumer.dart';
export 'src/presentation/layer_stack.dart';
export 'src/presentation/layer.dart';
export 'src/presentation/animated_layer.dart';
export 'src/presentation/collage_template.dart';
export 'src/presentation/render_controller.dart';
export 'src/presentation/render_mode_context.dart';
export 'src/presentation/sync_anchor.dart';
export 'src/presentation/sync_anchor_registry.dart';

// Presentation layer - Specialized sequences
export 'src/presentation/video_sequence.dart';
export 'src/presentation/text_sequence.dart';

// Presentation layer - Audio
export 'src/presentation/audio_track.dart';
export 'src/presentation/audio_source.dart';
export 'src/presentation/background_audio.dart';

// Presentation layer - Effects & Transitions
export 'src/presentation/cross_fade_transition.dart';

// Presentation layer - Fade widgets (for video rendering without saveLayer artifacts)
export 'src/presentation/fade.dart';
export 'src/presentation/fade_text.dart';
export 'src/presentation/fade_container.dart';

// Utilities
export 'src/utils/interpolate.dart';
export 'src/utils/text_layout_utils.dart';
export 'src/utils/ffmpeg_checker.dart';
export 'src/utils/video_path_resolver.dart';
export 'src/utils/impeller_checker.dart';

// Exceptions
export 'src/exceptions/fluvie_exceptions.dart';

// Domain layer - Configuration models
export 'src/domain/render_config.dart';
export 'src/domain/audio_config.dart';
export 'src/domain/embedded_video_config.dart';
export 'src/domain/spatial_properties.dart';
export 'src/domain/sync_anchor_info.dart';
export 'src/domain/driver.dart';
export 'src/domain/renderable.dart';

// Configuration
export 'src/config/fluvie_config.dart';

// Note: VideoEffect is not exported as it is not yet implemented.
// It will be available in a future release.

// Capture layer
export 'src/capture/frame_sequencer.dart';

// Encoding layer
export 'src/encoding/video_encoder_service.dart';
export 'src/encoding/video_probe_service.dart';
export 'src/encoding/frame_extraction_service.dart';
export 'src/encoding/video_frame_cache.dart';
export 'src/encoding/ffmpeg_provider/ffmpeg_provider.dart';
export 'src/encoding/ffmpeg_provider/ffmpeg_provider_registry.dart';
export 'src/encoding/ffmpeg_provider/process_ffmpeg_provider.dart';
export 'src/encoding/ffmpeg_provider/wasm_ffmpeg_provider.dart';

// Integration layer
export 'src/integration/render_service.dart';
export 'src/integration/video_exporter.dart';

// Preview layer
export 'src/preview/audio_preview_service.dart';

// Presentation layer - VideoPreview
export 'src/presentation/video_preview.dart';

// Utilities - File saving
export 'src/utils/file_saver.dart';

// Declarative API
export 'src/declarative/declarative.dart';

/// Primary plugin facade exposing platform-specific functionality.
class Fluvie {
  /// Returns platform version info from the registered platform implementation.
  Future<String?> getPlatformVersion() {
    return FluviePlatform.instance.getPlatformVersion();
  }
}
