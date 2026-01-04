import 'package:flutter/material.dart';
import 'fade.dart';
import 'time_consumer.dart';
import 'video_composition.dart';

/// A single layer within a [LayerStack] with video-specific properties.
///
/// Provides time-based visibility, opacity control, blend modes,
/// and transition effects. Unlike a plain widget in a Stack, a Layer
/// can automatically show/hide based on the current frame and apply
/// fade transitions.
///
/// Example:
/// ```dart
/// LayerStack(
///   children: [
///     Layer.background(
///       child: GradientBackground(),
///     ),
///     Layer(
///       id: 'title',
///       startFrame: 30,
///       endFrame: 120,
///       fadeInFrames: 15,
///       fadeOutFrames: 15,
///       child: TitleWidget(),
///     ),
///     Layer.overlay(
///       blendMode: BlendMode.screen,
///       child: Watermark(),
///     ),
///   ],
/// )
/// ```
class Layer extends StatelessWidget {
  /// Unique identifier for this layer (optional but useful for debugging).
  final String? id;

  /// The widget content of this layer.
  final Widget child;

  /// Frame at which this layer becomes visible (inclusive).
  ///
  /// If null, the layer is visible from the start of the composition.
  final int? startFrame;

  /// Frame at which this layer becomes invisible (exclusive).
  ///
  /// If null, the layer is visible until the end of the composition.
  final int? endFrame;

  /// Duration of fade-in transition in frames.
  ///
  /// The layer will fade from 0% to 100% opacity over this duration
  /// starting at [startFrame].
  final int fadeInFrames;

  /// Duration of fade-out transition in frames.
  ///
  /// The layer will fade from 100% to 0% opacity over this duration
  /// ending at [endFrame].
  final int fadeOutFrames;

  /// Base opacity of the layer (0.0 to 1.0).
  ///
  /// This is the maximum opacity the layer will reach after fade-in.
  final double opacity;

  /// Blend mode for compositing this layer with layers below.
  ///
  /// Defaults to [BlendMode.srcOver] (normal compositing).
  final BlendMode blendMode;

  /// Whether this layer is currently enabled.
  ///
  /// Disabled layers are completely removed from the tree and don't
  /// consume any resources.
  final bool enabled;

  /// Z-index for explicit ordering (higher values = on top).
  ///
  /// If null, order is determined by position in the children list.
  /// This is useful when you need to dynamically reorder layers.
  final int? zIndex;

  /// Curve for fade-in animation.
  final Curve fadeInCurve;

  /// Curve for fade-out animation.
  final Curve fadeOutCurve;

  /// Optional transform applied to the entire layer.
  final Matrix4? transform;

  /// Alignment for transform origin.
  final AlignmentGeometry transformAlignment;

  /// Creates a layer with the given properties.
  const Layer({
    super.key,
    this.id,
    required this.child,
    this.startFrame,
    this.endFrame,
    this.fadeInFrames = 0,
    this.fadeOutFrames = 0,
    this.opacity = 1.0,
    this.blendMode = BlendMode.srcOver,
    this.enabled = true,
    this.zIndex,
    this.fadeInCurve = Curves.easeOut,
    this.fadeOutCurve = Curves.easeIn,
    this.transform,
    this.transformAlignment = Alignment.center,
  });

  /// Creates a background layer that is always behind other layers.
  ///
  /// Background layers have a default zIndex of -1000 and fill the
  /// entire composition area.
  const Layer.background({
    super.key,
    this.id,
    required this.child,
    this.startFrame,
    this.endFrame,
    this.fadeInFrames = 0,
    this.fadeOutFrames = 0,
    this.opacity = 1.0,
    this.enabled = true,
  })  : blendMode = BlendMode.srcOver,
        zIndex = -1000,
        fadeInCurve = Curves.easeOut,
        fadeOutCurve = Curves.easeIn,
        transform = null,
        transformAlignment = Alignment.center;

  /// Creates an overlay layer that is always on top of other layers.
  ///
  /// Overlay layers have a default zIndex of 1000.
  const Layer.overlay({
    super.key,
    this.id,
    required this.child,
    this.startFrame,
    this.endFrame,
    this.fadeInFrames = 0,
    this.fadeOutFrames = 0,
    this.opacity = 1.0,
    this.blendMode = BlendMode.srcOver,
    this.enabled = true,
  })  : zIndex = 1000,
        fadeInCurve = Curves.easeOut,
        fadeOutCurve = Curves.easeIn,
        transform = null,
        transformAlignment = Alignment.center;

  /// Creates a layer with explicit timing and no fade transitions.
  ///
  /// Use this when you need precise control over when a layer appears
  /// and disappears without any opacity transitions.
  ///
  /// Example:
  /// ```dart
  /// Layer.timed(
  ///   startFrame: 30,
  ///   endFrame: 120,
  ///   child: TitleWidget(),
  /// )
  /// ```
  const Layer.timed({
    super.key,
    this.id,
    required this.startFrame,
    required this.endFrame,
    required this.child,
    this.opacity = 1.0,
    this.enabled = true,
  })  : fadeInFrames = 0,
        fadeOutFrames = 0,
        blendMode = BlendMode.srcOver,
        zIndex = null,
        fadeInCurve = Curves.easeOut,
        fadeOutCurve = Curves.easeIn,
        transform = null,
        transformAlignment = Alignment.center;

  /// Creates a layer with symmetric fade in and fade out transitions.
  ///
  /// This is a convenience constructor for the common case where you want
  /// the same fade duration for both entering and exiting.
  ///
  /// Example:
  /// ```dart
  /// Layer.faded(
  ///   fadeFrames: 20,
  ///   startFrame: 30,
  ///   endFrame: 150,
  ///   child: SubtitleWidget(),
  /// )
  /// ```
  const Layer.faded({
    super.key,
    this.id,
    required this.child,
    this.startFrame,
    this.endFrame,
    int fadeFrames = 15,
    this.enabled = true,
    Curve fadeCurve = Curves.easeInOut,
  })  : fadeInFrames = fadeFrames,
        fadeOutFrames = fadeFrames,
        opacity = 1.0,
        blendMode = BlendMode.srcOver,
        zIndex = null,
        fadeInCurve = fadeCurve,
        fadeOutCurve = fadeCurve,
        transform = null,
        transformAlignment = Alignment.center;

  /// Creates a layer that is visible for the full composition duration.
  ///
  /// Use this for elements that should always be visible, such as
  /// watermarks, persistent UI elements, or background decorations.
  ///
  /// Example:
  /// ```dart
  /// Layer.fullDuration(
  ///   child: Watermark(),
  /// )
  /// ```
  const Layer.fullDuration({
    super.key,
    this.id,
    required this.child,
    this.opacity = 1.0,
    this.enabled = true,
  })  : startFrame = null,
        endFrame = null,
        fadeInFrames = 0,
        fadeOutFrames = 0,
        blendMode = BlendMode.srcOver,
        zIndex = null,
        fadeInCurve = Curves.easeOut,
        fadeOutCurve = Curves.easeIn,
        transform = null,
        transformAlignment = Alignment.center;

  @override
  Widget build(BuildContext context) {
    // If disabled, don't render anything
    if (!enabled) {
      return const SizedBox.shrink();
    }

    // Use TimeConsumer to get frame-based rendering
    return TimeConsumer(
      builder: (context, frame, globalProgress) {
        final composition = VideoComposition.of(context);
        final totalDuration = composition?.durationInFrames ?? 1;

        // Calculate visibility window
        final start = startFrame ?? 0;
        final end = endFrame ?? totalDuration;

        // Check if layer is visible at this frame
        if (frame < start || frame >= end) {
          return const SizedBox.shrink();
        }

        // Calculate opacity with fade transitions
        double computedOpacity = opacity;

        // Fade in
        if (fadeInFrames > 0 && frame < start + fadeInFrames) {
          final fadeProgress = (frame - start) / fadeInFrames;
          computedOpacity *= fadeInCurve.transform(
            fadeProgress.clamp(0.0, 1.0),
          );
        }

        // Fade out
        if (fadeOutFrames > 0 && frame >= end - fadeOutFrames) {
          final fadeProgress = (end - frame) / fadeOutFrames;
          computedOpacity *= fadeOutCurve.transform(
            fadeProgress.clamp(0.0, 1.0),
          );
        }

        Widget result = child;

        // Apply transform if specified
        if (transform != null) {
          result = Transform(
            transform: transform!,
            alignment: transformAlignment,
            child: result,
          );
        }

        // Apply opacity using Fade widget (avoids saveLayer artifacts)
        // Note: For blend modes other than srcOver, we still need ShaderMask
        // which uses saveLayer. Users should avoid non-standard blend modes
        // for video rendering, or ensure the blended content has opaque backgrounds.
        if (blendMode != BlendMode.srcOver) {
          // For non-standard blend modes, use ShaderMask
          // Warning: This uses saveLayer and may cause transparency artifacts
          result = ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: computedOpacity),
                  Colors.white.withValues(alpha: computedOpacity),
                ],
              ).createShader(bounds);
            },
            blendMode: blendMode,
            child: result,
          );
        } else if (computedOpacity < 1.0) {
          // Use Fade instead of Opacity to avoid saveLayer
          // Children must be fade-aware widgets (FadeText, FadeContainer, etc.)
          // for opacity to be applied correctly
          result = Fade(
            opacity: computedOpacity.clamp(0.0, 1.0),
            child: result,
          );
        }

        return result;
      },
    );
  }
}
