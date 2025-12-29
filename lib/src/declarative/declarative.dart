/// Declarative API for Fluvie video composition.
///
/// This library provides a declarative, widget-based approach to creating
/// video compositions. Instead of imperatively managing frames and timing,
/// you can compose videos using familiar Flutter widget patterns.
///
/// ## Quick Start
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
///       background: Background.gradient(
///         colors: {0: Colors.blue, 60: Colors.purple},
///       ),
///       children: [
///         VCenter(
///           child: AnimatedText.slideUpFade(
///             'Hello World',
///             style: TextStyle(fontSize: 64, color: Colors.white),
///           ),
///         ),
///       ],
///     ),
///   ],
/// )
/// ```
///
/// ## Key Features
///
/// - **Scene-based composition**: Organize your video into scenes with automatic
///   timing and transitions.
/// - **Declarative animations**: Use [AnimatedProp] and [PropAnimation] for
///   simple, composable animations.
/// - **Layout widgets**: Flutter-like layout with [VStack], [VRow], [VColumn],
///   [VCenter], [VPositioned].
/// - **Text animations**: [AnimatedText], [TypewriterText], [CounterText] for
///   animated text effects.
/// - **Visual effects**: [ParticleEffect], [EffectOverlay], [MaskedClip] for
///   post-processing.
/// - **Cinematography**: [CameraFocus], [Loop], [AnimatedChart] for advanced
///   camera work and data visualization.
library;

// Core - Video and Scene composition
export 'core/core.dart';

// Layout - Flutter-mirrored layout widgets with video timing
export 'layout/layout.dart';

// Animations - Core animations, entry effects, and ambient effects
// (includes AnimatedProp, PropAnimation, Stagger, SlideIn, EntryAnimation, FloatingVibe, etc.)
export 'animations/animations.dart';

// Background - Animated backgrounds and gradients
export 'background/background_exports.dart';

// Text - Animated text widgets
export 'text/text.dart';

// Effects - Visual effects and post-processing
export 'effects/effects.dart';

// Helpers - Layout presets and helper widgets
export 'helpers/helpers.dart';

// Cinematography - Camera effects, loops, and charts
export 'cinematography/cinematography.dart';

// Utilities - Easing curves and frame range helpers
export 'utils/utils.dart';

// Templates - Spotify Wrapped style templates (moved to lib/src/templates/)
export '../templates/templates.dart';

// Audio - Audio-reactive animations and BPM detection
export 'audio/audio.dart';
