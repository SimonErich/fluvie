/// Write a video like a Flutter screen: widgets in, a real video file out.
///
/// This is the authoring surface, everything you type inside a `Video`:
///
/// ```dart
/// import 'package:fluvie/fluvie.dart';
/// ```
///
/// The pipeline surface (capture, sandboxes, encoders) lives behind
/// `package:fluvie/rendering.dart`; the two barrels are disjoint. `src/`
/// stays private.
library;

export 'src/animation/animate_extension.dart';
export 'src/animation/animation.dart';
export 'src/animation/animation_effect.dart';
export 'src/animation/effect_kind.dart';
export 'src/animation/frame_builder.dart' show FrameBuilder;
export 'src/animation/runtime/frame_context.dart' show FrameContext;
export 'src/audio/audio.dart';
export 'src/audio/generative_audio.dart';
export 'src/captions/caption_position.dart' show CaptionPosition;
export 'src/captions/caption_style.dart' show CaptionStyle;
export 'src/captions/captions.dart';
export 'src/composition/adaptive.dart' show Adaptive;
export 'src/composition/background/background.dart';
export 'src/composition/box.dart';
export 'src/composition/camera/camera.dart';
export 'src/composition/photo_frame.dart';
export 'src/composition/runtime/aspect_scope.dart' show AspectScope;
export 'src/composition/runtime/timeline_probe.dart';
export 'src/composition/scene.dart';
export 'src/composition/timeline.dart';
export 'src/composition/timeline_label.dart';
export 'src/composition/timeline_schedule.dart';
export 'src/composition/transition/shared_element.dart';
export 'src/composition/video.dart';
export 'src/core/anchor.dart';
export 'src/core/angle.dart';
export 'src/core/animation_phase.dart';
export 'src/core/aspect.dart';
export 'src/core/audio/audio_source.dart' show AudioSource;
export 'src/core/audio_band.dart';
export 'src/core/captions/caption_cue.dart' show CaptionCue, CaptionCueWord;
export 'src/core/captions/caption_word.dart';
export 'src/core/defaults.dart';
export 'src/core/ease.dart';
export 'src/core/edge.dart';
export 'src/core/errors/fluvie_encode_exception.dart';
export 'src/core/errors/fluvie_generative_exception.dart';
export 'src/core/errors/fluvie_render_exception.dart';
export 'src/core/errors/fluvie_snapshot_unavailable_error.dart' show FluvieSnapshotUnavailableError;
export 'src/core/errors/fluvie_spec_error.dart';
export 'src/core/errors/fluvie_timing_error.dart';
export 'src/core/export.dart';
export 'src/core/keyframe.dart';
export 'src/core/media/clip_audio.dart';
export 'src/core/media/generative_kind.dart';
export 'src/core/media/generative_source.dart';
export 'src/core/media/media_source.dart';
export 'src/core/noise/noise_source.dart';
export 'src/core/particles/particles.dart';
export 'src/core/quality.dart';
export 'src/core/repeat.dart';
export 'src/core/snapshot/snapshot_viewport.dart' show SnapshotViewport;
export 'src/core/stagger.dart';
export 'src/core/stagger_origin.dart';
export 'src/core/time.dart' hide ComputedTime;
export 'src/core/time_extensions.dart';
export 'src/core/time_range.dart';
export 'src/core/time_scope.dart';
export 'src/core/timing.dart';
export 'src/core/transition.dart';
export 'src/core/trigger.dart';
export 'src/core/video_size.dart';
export 'src/core/wipe_shape.dart';
export 'src/diagnostics/inspector_model.dart' show InspectorModel, InspectorMotion;
export 'src/elements/annotations/arrow.dart' show Arrow;
export 'src/elements/annotations/callout.dart' show Callout;
export 'src/elements/annotations/connector.dart' show Connector;
export 'src/elements/annotations/lower_third.dart' show LowerThird;
export 'src/elements/annotations/shape.dart' show Shape;
export 'src/elements/annotations/spotlight.dart' show Spotlight;
export 'src/elements/annotations/title_card.dart' show TitleCard;
export 'src/elements/bars/bars.dart' show Bars;
export 'src/elements/chart/chart.dart';
export 'src/elements/chart/data/chart_point.dart';
export 'src/elements/chart/data/chart_series.dart';
export 'src/elements/clip.dart';
export 'src/elements/code/code.dart' show Code;
export 'src/elements/code/code_reveal.dart' show CodeReveal;
export 'src/elements/counter.dart';
export 'src/elements/generative_media.dart';
export 'src/elements/image.dart';
export 'src/elements/markdown/markdown.dart' show Markdown;
export 'src/elements/markdown/render/markdown_style.dart' show MarkdownStyle;
// MermaidTheme is already public via theme/fluvie_tokens.dart; re-exporting it
// here too would be an ambiguous_export.
export 'src/elements/mermaid/mermaid.dart' show Mermaid;
export 'src/elements/mermaid/mermaid_reveal.dart' show MermaidReveal;
export 'src/elements/snapshot/device_frame.dart' show DeviceFrame;
export 'src/elements/snapshot/snapshot.dart' show Snapshot;
export 'src/elements/terminal/terminal.dart' show Terminal;
export 'src/elements/terminal/terminal_chrome.dart' show TerminalChrome;
export 'src/elements/terminal/terminal_line.dart' show TerminalLine;
export 'src/elements/typewriter.dart';
export 'src/elements/webview/html.dart' show Html;
export 'src/elements/webview/webview.dart' show WebView;
export 'src/rendering/runtime/frame_provider.dart';
export 'src/rendering/runtime/render_controller.dart';
export 'src/rendering/runtime/render_controller_scope.dart';
export 'src/rendering/runtime/render_mode.dart';
export 'src/rendering/runtime/render_mode_context.dart';
export 'src/serialization/anchor_table.dart' show AnchorTable;
export 'src/serialization/animation_spec.dart' show AnimationSpec, knownAnimationPresets;
export 'src/serialization/background_spec.dart'
    show BackgroundSpec, knownBackgroundKinds, knownBackgroundProps;
export 'src/serialization/element_spec.dart' show ElementSpec, knownElementProps, knownElementTypes;
export 'src/serialization/scene_spec.dart' show SceneSpec;
export 'src/serialization/spec_validation.dart'
    show FluvieSpecWarning, assertNoUnknownSpecProps, unknownSpecProps;
export 'src/serialization/video_spec.dart' show VideoSpec, buildVideo;
export 'src/serialization/video_spec_schema.dart' show videoSpecSchema;
export 'src/templates/builtin/stat_highlight.dart' show StatHighlight, StatHighlightProps;
export 'src/templates/builtin/title_intro.dart' show TitleIntro, TitleIntroProps;
export 'src/templates/video_template.dart' show VideoTemplate;
export 'src/theme/build_context_tokens.dart';
export 'src/theme/fluvie_theme.dart' show FluvieTheme;
export 'src/theme/fluvie_tokens.dart';
export 'src/theme/fluvie_tokens_scope.dart';
export 'src/theme/palette.dart' show Palette;
export 'src/theme/type_scale.dart' show TypeScale;
export 'src/timing/scene_scope.dart';
export 'src/timing/timeline/debug_timeline.dart';
export 'src/timing/timeline/resolved_timeline.dart';
export 'src/timing/timeline/timeline_anchor.dart';
export 'src/timing/timeline/timeline_row.dart';
export 'src/timing/video_scope.dart';
