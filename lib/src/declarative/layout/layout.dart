/// Layout widgets for declarative video composition.
///
/// ## V-Prefix Convention
///
/// Widgets in this library use the "V" prefix (for "Video") to indicate they
/// are video-aware versions of Flutter's standard layout widgets. Each V-widget
/// wraps its Flutter counterpart with additional timing and animation capabilities.
///
/// | V-Widget | Flutter Equivalent | Additional Features |
/// |----------|-------------------|---------------------|
/// | [VCenter] | [Center] | startFrame, endFrame, fadeIn/fadeOut |
/// | [VRow] | [Row] | Timing, stagger animations |
/// | [VColumn] | [Column] | Timing, stagger animations |
/// | [VStack] | [Stack] | Frame-based visibility |
/// | [VPadding] | [Padding] | Timing support |
/// | [VSizedBox] | [SizedBox] | Timing support |
/// | [VPositioned] | [Positioned] | Timing support |
///
/// ## When to Use V-Widgets vs Regular Widgets
///
/// Use V-widgets when you need:
/// - Time-based visibility (startFrame/endFrame)
/// - Fade transitions (fadeInFrames/fadeOutFrames)
/// - Staggered child animations (VRow, VColumn)
///
/// Use regular Flutter widgets when:
/// - The widget should always be visible within its parent's timeframe
/// - No timing or fade effects are needed
/// - You're building static content inside a timed container
///
/// ## Why Layer/Scene/Video Don't Have V-Prefix
///
/// Composition primitives like [Layer], [Scene], and [Video] don't use the
/// V-prefix because they are unique to video composition—there are no Flutter
/// equivalents to distinguish them from. The V-prefix is specifically for
/// layout widgets that have direct Flutter counterparts.
///
/// ## Example
///
/// ```dart
/// Scene(
///   durationInFrames: 120,
///   children: [
///     VCenter(
///       startFrame: 0,
///       endFrame: 60,
///       fadeInFrames: 15,
///       child: Text('First half'),
///     ),
///     VCenter(
///       startFrame: 60,
///       endFrame: 120,
///       fadeInFrames: 15,
///       child: Text('Second half'),
///     ),
///   ],
/// )
/// ```
library;

export 'asymmetric_layout.dart';
export 'stagger_config.dart';
export 'v_center.dart';
export 'v_column.dart';
export 'v_padding.dart';
export 'v_positioned.dart';
export 'v_row.dart';
export 'v_sized_box.dart';
export 'v_stack.dart';
export 'video_timing_mixin.dart';
