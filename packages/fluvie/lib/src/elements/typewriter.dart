import 'package:flutter/widgets.dart' show BuildContext, StatelessWidget, Text, TextStyle, Widget;
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/reveal/glyph_reveal.dart';
import 'package:fluvie/src/elements/runtime/element_shared.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';

/// Reveals [text] one glyph at a time, driven entirely by the frame — an
/// intrinsic element whose content behaviour is the only thing its constructor
/// controls.
///
/// The visible glyph count is `floor(elapsed / speed)` clamped to
/// `[0, text.length]`, where `elapsed` is the frames since the enclosing time
/// scope began ([FrameProvider] is the only clock): at [speed]
/// frames per glyph the text fills in linearly and holds once complete. A
/// partial glyph never shows — the floor means a glyph appears only when its
/// whole reveal time has passed, so the reveal renders the same on every
/// render.
///
/// ```dart
/// Typewriter('Typed out one glyph at a time.', speed: 18.frames, caret: true)
///     .animate([Animation.fadeIn()]);
/// ```
///
/// [caret] appends a blinking `|` that turns on for the first half of a
/// frame-pinned [caretPeriod] and off for the second, so the blink is
/// deterministic across machines. Transforms and effects come through
/// `.animate()` only — the constructor takes content parameters ([speed],
/// [caret], [style]) and nothing else. [shared] wraps the result in a
/// `SharedElement` for a hero morph across a scene boundary.
final class Typewriter extends StatelessWidget {
  /// Types out [text] at [speed] frames per glyph, optionally trailing a
  /// blinking [caret], in [style].
  // coverage:ignore-line: const-ctor artifact, behavior pinned by typewriter tests
  const Typewriter(
    this.text, {
    this.speed = const Time.frames(2),
    this.caret = false,
    this.style,
    this.shared,
    super.key,
  });

  /// The full string this typewriter reveals glyph by glyph.
  final String text;

  /// How long each glyph takes to appear; the default reveals two frames per
  /// glyph. Resolved against the enclosing scope, so a `0.1.seconds` speed
  /// scales with fps.
  final Time speed;

  /// Whether to trail a blinking caret after the revealed glyphs.
  final bool caret;

  /// The text style, or `null` to inherit the ambient `DefaultTextStyle`.
  final TextStyle? style;

  /// An optional hero anchor: when non-null the typewriter morphs across the
  /// boundary it shares with the same anchor in the adjacent scene. `null`
  /// mounts no `SharedElement`.
  final Anchor? shared;

  /// The blink period in frames: the caret is on for the first half and off
  /// for the second (golden-pinned at 16 frames so goldens stay stable).
  static const int caretPeriod = 16;

  @override
  Widget build(BuildContext context) {
    final frame = FrameProvider.of(context).frame;
    final scope = TimeScopeProvider.of(context);
    final visible = Text(_visibleText(frame, scope), style: style);
    return wrapShared(shared, visible);
  }

  /// The substring to paint at [frame] within [scope], plus the caret when on.
  String _visibleText(int frame, TimeScopeData scope) {
    final elapsed = frame - scope.startFrame;
    final revealed = glyphsRevealed(
      elapsed: elapsed,
      speed: speed,
      totalGlyphs: text.length,
      scope: scope,
    );
    final shown = text.substring(0, revealed);
    if (!caret) return shown;
    return caretBlinkOn(elapsed, caretPeriod) ? '$shown|' : shown;
  }
}
