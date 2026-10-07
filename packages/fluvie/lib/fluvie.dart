/// Write a video like a Flutter screen: widgets in, a real video file out.
///
/// This is the authoring surface, everything you type inside a `Video`:
///
/// ```dart
/// import 'package:fluvie/fluvie.dart';
/// ```
///
/// The pipeline surface (capture, sandboxes, encoders) lives behind
/// `package:fluvie/rendering.dart`. The barrels share value types; composition
/// authoring stays separate from renderer hosting. `src/` stays private.
library;

export 'src/animation/animate_extension.dart';
export 'src/animation/animation.dart';
export 'src/animation/animation_effect.dart';
export 'src/animation/effect.dart' show Effect, EffectsExtension;
export 'src/animation/effect_kind.dart';
export 'src/animation/frame_builder.dart' show FrameBuilder;
export 'src/animation/keyframed_number.dart' show EffectFrame, KeyframedNumber;
export 'src/animation/runtime/effect_layer.dart' show EffectLayer;
export 'src/animation/runtime/frame_context.dart' show FrameContext;
export 'src/animation/runtime/local_motion_scope.dart' show LocalMotionScope;
export 'src/audio/audio.dart';
export 'src/audio/generative_audio.dart';
export 'src/captions/caption_position.dart' show CaptionPosition;
export 'src/captions/caption_style.dart' show CaptionStyle;
export 'src/captions/captions.dart';
export 'src/composition/adaptive.dart' show Adaptive;
export 'src/composition/background/background.dart';
export 'src/composition/box.dart';
export 'src/composition/camera/camera.dart';
export 'src/composition/clip_transition.dart' show ClipTransition, ClipTransitionGroup;
export 'src/composition/composition_resource_scope.dart' show CompositionResourceScope;
export 'src/composition/composition_resources.dart' show ClipResource, CompositionResources;
export 'src/composition/introspection/animation_introspection.dart' show AnimationIntrospection;
export 'src/composition/introspection/element_introspection.dart' show ElementIntrospection;
export 'src/composition/introspection/frame_span.dart' show FrameSpan;
export 'src/composition/introspection/scene_introspection.dart' show SceneIntrospection;
export 'src/composition/introspection/timeline_introspection.dart'
    show TimelineIntrospection, introspectTimeline;
export 'src/composition/photo_frame.dart';
export 'src/composition/runtime/aspect_scope.dart' show AspectScope;
export 'src/composition/runtime/collectible_children.dart' show CollectibleChildren;
export 'src/composition/runtime/scene_tree_walk.dart' show walkSceneTree, walkWidgetTree;
export 'src/composition/runtime/spec_element_id.dart' show ElementId, SpecElementId;
export 'src/composition/runtime/timeline_probe.dart';
export 'src/composition/scene.dart';
export 'src/composition/timeline.dart';
export 'src/composition/timeline_label.dart';
export 'src/composition/timeline_schedule.dart';
export 'src/composition/transition/shared_element.dart';
export 'src/composition/transition/transition_strategy.dart'
    show
        TransitionStrategy,
        hasTransitionStrategy,
        registerTransitionStrategy,
        strategyFor,
        unregisterTransitionStrategy;
export 'src/composition/video.dart';
export 'src/core/anchor.dart';
export 'src/core/angle.dart';
export 'src/core/animation_phase.dart';
export 'src/core/aspect.dart';
export 'src/core/audio/audio_automation.dart';
// The whole sealed family, like the MediaSource one below: a custom encoder
// pattern-matches the subtypes (a memory source's bytes have no string form).
export 'src/core/audio/audio_source.dart'
    show AssetAudioSource, AudioSource, FileAudioSource, MemoryAudioSource, NetworkAudioSource;
export 'src/core/audio/audio_time_map.dart' show AudioTimeMap;
export 'src/core/audio_band.dart';
export 'src/core/captions/caption_cue.dart' show CaptionCue, CaptionCueWord;
export 'src/core/captions/caption_word.dart';
export 'src/core/color/cube_lut.dart' show CubeLut;
export 'src/core/color/tone_curve.dart' show ToneCurve;
export 'src/core/defaults.dart';
export 'src/core/ease.dart';
export 'src/core/edge.dart';
export 'src/core/encoder_options.dart' show EncoderPreset, ExportCodec, ExportPixelFormat;
export 'src/core/errors/fluvie_capability_exception.dart';
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
export 'src/core/placement.dart';
export 'src/core/quality.dart';
export 'src/core/repeat.dart';
export 'src/core/snapshot/snapshot_viewport.dart' show SnapshotViewport;
export 'src/core/stagger.dart';
export 'src/core/stagger_origin.dart';
export 'src/core/svg_path.dart' show pathFromSvg;
export 'src/core/time.dart'
    hide ComputedTime, resolveSourceTimeFrames, resolveSourceTimeOffset, resolveSourceTimeSeconds;
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
export 'src/elements/placed.dart' show Placed;
export 'src/elements/placed_overrides.dart' show PlacedOverrides;
export 'src/elements/snapshot/device_frame.dart' show DeviceFrame;
export 'src/elements/snapshot/snapshot.dart' show Snapshot;
export 'src/elements/split_text.dart' show SplitText, TextSplit, splitTextParts;
export 'src/elements/terminal/terminal.dart' show Terminal;
export 'src/elements/terminal/terminal_chrome.dart' show TerminalChrome;
export 'src/elements/terminal/terminal_line.dart' show TerminalLine;
export 'src/elements/typewriter.dart';
export 'src/elements/webview/html.dart' show Html;
export 'src/elements/webview/webview.dart' show WebView;
export 'src/rendering/assets/project_asset_bundle.dart' show ProjectAssetBundle, ProjectAssetReader;
export 'src/rendering/runtime/frame_provider.dart';
export 'src/rendering/runtime/live_playback_controller.dart';
export 'src/rendering/runtime/live_player.dart';
export 'src/rendering/runtime/preview_audio_controller.dart' show PreviewAudioController;
export 'src/rendering/runtime/preview_media_scope.dart' show PreviewMediaScope;
export 'src/rendering/runtime/render_controller.dart';
export 'src/rendering/runtime/render_controller_scope.dart';
export 'src/rendering/runtime/render_mode.dart';
export 'src/rendering/runtime/render_mode_context.dart';
export 'src/rendering/runtime/video_preview.dart' show VideoPreview;
export 'src/serialization/anchor_table.dart' show AnchorTable;
export 'src/serialization/animation_spec.dart' show AnimationSpec, knownAnimationPresets;
export 'src/serialization/audio_automation.dart';
export 'src/serialization/audio_track_spec.dart' show AudioTrackSpec;
export 'src/serialization/background_spec.dart'
    show BackgroundSpec, knownBackgroundKinds, knownBackgroundProps;
export 'src/serialization/bundle_media.dart' show BundleMedia;
export 'src/serialization/codecs/alignment_codec.dart'
    show decodeAlignment, encodeAlignment, namedAlignments;
export 'src/serialization/codecs/color_codec.dart' show decodeColor, encodeColor;
export 'src/serialization/codecs/curve_codec.dart' show decodeCurve, encodeCurve;
export 'src/serialization/codecs/curve_codec.dart' show namedEases;
export 'src/serialization/codecs/keyframe_codec.dart' show decodeKeyframe, encodeKeyframe;
export 'src/serialization/codecs/placement_codec.dart' show decodePlacement, encodePlacement;
export 'src/serialization/codecs/time_codec.dart' show decodeTime;
export 'src/serialization/effect_builder.dart' show buildEffect;
export 'src/serialization/effect_spec.dart' show EffectParam, EffectSpec, EffectSpecKind;
export 'src/serialization/element_spec.dart' show ElementSpec, knownElementProps, knownElementTypes;
export 'src/serialization/element_transition_spec.dart'
    show
        ElementTransitionLayout,
        ElementTransitionSpec,
        ElementTransitionWindow,
        resolveElementTransitionLayout;
export 'src/serialization/lane_spec.dart' show LaneKind, LaneSpec;
export 'src/serialization/master_spec.dart'
    show MasterChildSpec, MasterElementSpec, MasterSpec, PlaceholderSpec, resolveSceneMaster;
export 'src/serialization/media_file_base.dart' show MediaFileBase;
export 'src/serialization/scene_spec.dart' show NotesSpec, SceneLayout, SceneSpec, StepSpec;
export 'src/serialization/spec_validation.dart'
    show FluvieSpecWarning, assertNoUnknownSpecProps, unknownSpecProps;
export 'src/serialization/theme_spec.dart' show ThemeSpec;
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
