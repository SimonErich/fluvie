import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_example/render/composition_entry.dart';

/// The acceptance composition: 320x240 @ 30 fps, 48 frames, one scene whose
/// background color derives from the current frame with integer math only —
/// bit-stable by construction.
const demoComposition = CompositionEntry(key: 'demo', video: demoVideo);

/// Builds the `demo` composition. The fps is the `Video` default (30).
Video demoVideo() => Video(
  size: const VideoSize(320, 240),
  scenes: const [
    Scene(
      duration: Time.frames(48),
      // A scene lays its children out in a Stack, and a childless ColoredBox
      // under loose constraints would collapse to zero, so fill the canvas.
      children: [Positioned.fill(child: _FrameBackground())],
    ),
  ],
);

/// A solid background whose RGB channels are pure integer functions of the
/// current frame index.
class _FrameBackground extends StatelessWidget {
  const _FrameBackground();

  @override
  Widget build(BuildContext context) {
    final f = FrameProvider.of(context).frame;
    return ColoredBox(color: Color.fromARGB(255, (f * 5) % 256, (f * 3) % 256, (f * 7) % 256));
  }
}
