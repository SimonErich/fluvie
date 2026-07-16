import 'dart:async' show unawaited;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:fluvie/src/rendering/runtime/live_playback_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_mode.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';

/// Plays a composition live: a `Ticker` drives the [controller]'s frame
/// clock, and the same per-frame rebuild path capture uses delivers each
/// frame to [child].
///
/// The player is deliberately dumb: it owns the ticker, mounts
/// [RenderMode.preview] (live mode — wall-clock and platform views are
/// allowed, nothing is being encoded), and republishes the controller's
/// frame. What plays, pauses, or holds is entirely the [controller]'s
/// business, so the same widget serves a video preview, a scrubber, or any
/// consumer that paces the clock itself.
///
/// ```dart
/// final playback = LivePlaybackController(fps: 30);
/// runApp(LivePlayer(controller: playback, child: video));
/// playback.play();
/// ```
final class LivePlayer extends StatefulWidget {
  /// Mounts [child] on [controller]'s live frame clock.
  const LivePlayer({required this.controller, required this.child, super.key});

  /// The clock face driving this player. The player starts and stops its
  /// ticker to match the controller's playback state.
  final LivePlaybackController controller;

  /// The composition (or any frame-driven subtree) being played.
  final Widget child;

  @override
  State<LivePlayer> createState() => _LivePlayerState();
}

class _LivePlayerState extends State<LivePlayer> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    // Dispatch through `widget.controller` (not a tear-off) so swapping
    // controllers in didUpdateWidget rewires the tick target too.
    _ticker = createTicker((elapsed) => widget.controller.handleTick(elapsed));
    widget.controller.addListener(_syncTicker);
    _syncTicker();
  }

  @override
  void didUpdateWidget(LivePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.controller, widget.controller)) return;
    oldWidget.controller.removeListener(_syncTicker);
    _ticker.stop();
    widget.controller.addListener(_syncTicker);
    _syncTicker();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncTicker);
    _ticker.dispose();
    super.dispose();
  }

  /// Keeps the ticker running exactly while the controller plays. The ticker
  /// restarts from zero elapsed on every play, which is the rebase contract
  /// [LivePlaybackController.handleTick] resolves frames against.
  void _syncTicker() {
    final playing = widget.controller.state == LivePlaybackState.playing;
    if (playing && !_ticker.isActive) {
      // The TickerFuture resolves when the ticker stops; playback state is
      // tracked on the controller, so nothing awaits it.
      unawaited(_ticker.start());
    } else if (!playing && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  Widget build(BuildContext context) => RenderModeContext(
    mode: RenderMode.preview,
    child: RenderControllerScope(
      controller: widget.controller.renderController,
      child: widget.child,
    ),
  );
}
