import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

/// Resolves an `Audio.sfx(at:)` [trigger] to an absolute composition frame at
/// composition [scope], so `stageAudioMix` can convert it
/// to an `AudioTrackNode.delayMs`.
///
/// An sfx fires at the composition level, not inside any scene or element
/// window, so only the composition-scoped triggers resolve here: a `null`
/// trigger (the default) fires at the composition start (frame 0), and
/// [Trigger.at] resolves its [Time] against [scope] — an absolute or relative
/// time alike, the fraction measured against the whole composition window. Every
/// other trigger (`sceneStart`/`sceneEnd`/`after`/`whenStarts`/`previous`/`beat`)
/// references a scene, element timeline, or beat grid that the composition-level
/// mix has no context for, so it surfaces an honest [FluvieTimingError] naming
/// the unsupported trigger rather than guessing a frame.
int resolveSfxFrame(Trigger? trigger, TimeScopeData scope) => switch (trigger) {
  null => 0,
  AbsoluteTrigger(:final time) => scope.startFrame + time.resolveFrames(scope),
  _ => throw FluvieTimingError(
    'Audio.sfx(at: $trigger) is not a composition-scoped trigger. A one-shot '
    'sound effect fires at the composition level, so its `at:` must be '
    'Trigger.at(<time>) (or left null to fire at the start) — '
    '${trigger.runtimeType} references a scene, element, or beat grid the mix '
    'cannot resolve against.',
  ),
};
