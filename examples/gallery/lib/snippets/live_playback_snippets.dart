// Compiled, tested snippets for the live-playback docs. They live here, not
// hand-typed in Markdown, so the documentation never drifts from a real API.
// Each `#docregion` flows into one fence via a `<!-- code-excerpt -->` marker.

// The playback snippets deliberately repeat the receiver so each line reads
// standalone in its docs fence; a cascade would hide the API being named.
// ignore_for_file: cascade_invocations
import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';

/// A live player over a composition: the ticker drives the same frame clock
/// capture steps, so what plays is what renders.
// #docregion live-player
Widget playLive(Video video) {
  final playback = LivePlaybackController(fps: video.fps, totalFrames: video.totalFrames);
  playback.play();
  return LivePlayer(controller: playback, child: video);
}
// #enddocregion live-player

/// The playback surface: exact seeks, held states, and a segment that stops
/// on its end frame.
// #docregion playback-controls
Future<void> driveIt(LivePlaybackController playback) async {
  playback.play(); // free-run from the current frame
  playback.pause(); // freeze right here
  playback.seek(120); // land exactly on frame 120
  playback.hold(120); // land there and stay (back-navigation wants this)
  playback.rate = 1.5; // one-and-a-half speed, rebased without a jump
  await playback.playRange(120, 180); // play a segment, hold its last frame
}
// #enddocregion playback-controls

/// Static timeline introspection: scene bounds and element windows as plain
/// frame spans, without mounting anything.
// #docregion introspection
void whereThingsAre(Video video, Anchor logo) {
  final introspection = introspectTimeline(video);
  final scene = introspection.scenes[1];
  debugPrint('scene 1 runs ${scene.span.start}..${scene.span.end}');

  final element = introspection.elementForAnchor(logo)!;
  debugPrint('the logo is alive ${element.window}');
  debugPrint('its entrance plays ${element.enterSpan}');
}

// #enddocregion introspection

/// Dynamic live content: a subtree that mounts mid-playback and animates in
/// from that moment, detached from the composition's resolved plan.
// #docregion local-motion-scope
Widget lateArrival({required bool revealed}) => LocalMotionScope(
  child: revealed ? const Text('surprise!').animate([Animation.fadeIn()]) : const SizedBox.shrink(),
);
// #enddocregion local-motion-scope
