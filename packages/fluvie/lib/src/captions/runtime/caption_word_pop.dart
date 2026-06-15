import 'package:flutter/animation.dart' show Curves;
import 'package:fluvie/src/animation/runtime/motion_runner.dart';
import 'package:fluvie/src/animation/stagger/stagger_offsets.dart';
import 'package:fluvie/src/core/captions/caption_cue.dart';
import 'package:fluvie/src/core/stagger.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/timing.dart';
import 'package:fluvie/src/timing/resolver/trigger_resolver.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

/// The default per-word stagger gap for a cue with no word-level timing: 80 ms,
/// the recurring stagger gap.
const Time _defaultWordGap = Time.ms(80);

/// The pop window each word scales up over: the scale rises from `0` to `1` on
/// the pop spring across these frames.
const Time _popWindow = Time.ms(350);

/// The spring word-pop uses, mirroring `Animation.pop`: scale `0` to natural
/// with a small overshoot. Reusing a spring (not a bespoke curve) keeps the
/// caption pop on the same motion math as every other element.
const Spring _popSpring = Spring.bouncy;

/// The absolute start frame of each word in [cue], resolved against [scope].
///
/// When the cue carries word-level timing, each word starts at its own `at`;
/// otherwise the words stagger from the cue start by the shared
/// [staggerOffsetFrames] (an 80 ms `Stagger.each`), so word-pop reuses the same
/// stagger math as `.animate()` rather than inventing its own.
List<int> wordStartFrames(CaptionCue cue, TimeScopeData scope) {
  if (cue.words.isNotEmpty) {
    return [for (final word in cue.words) word.at.resolveFrames(scope)];
  }
  final count = _wordCount(cue.text);
  if (count == 0) return const [];
  final cueStart = cue.start.resolveFrames(scope);
  final offsets = staggerOffsetFrames(
    stagger: const Stagger.each(_defaultWordGap),
    childCount: count,
    scope: scope,
  );
  return [for (final offset in offsets) cueStart + offset];
}

/// The pop scale of a word at [frame] given its [wordStartFrame]: `0` before it
/// starts, rising on the pop spring across the pop window, settling to exactly
/// `1`.
///
/// This delegates to [MotionRunner.progress] with the pop spring, so the caption
/// word-pop runs on the exact progress pipeline `.animate()` uses. The scale is
/// the progress directly (a scale-`0`-to-natural enter).
double wordPopScale({
  required int frame,
  required int wordStartFrame,
  required int fps,
}) {
  final popFrames = _popWindow.resolveFrames(
    TimeScopeData(fps: fps, startFrame: 0, durationFrames: 0),
  );
  final span = ResolvedSpan(wordStartFrame, wordStartFrame + popFrames);
  return MotionRunner.progress(
    frame: frame,
    span: span,
    ease: Curves.linear,
    fps: fps,
    spring: _popSpring,
  );
}

/// The index of the active word in [cue] at [frame] for karaoke: the latest
/// word whose start has passed, or `-1` before the first word.
int activeWordIndex(CaptionCue cue, {required int frame, required TimeScopeData scope}) {
  final starts = wordStartFrames(cue, scope);
  var active = -1;
  for (var i = 0; i < starts.length; i++) {
    if (frame >= starts[i]) active = i;
  }
  return active;
}

/// The number of whitespace-delimited words in [text].
int _wordCount(String text) => text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
