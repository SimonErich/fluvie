import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_example/render/composition_entry.dart';

/// The acceptance composition: 320x240 @ 30 fps, 48 frames, one
/// scene whose background color derives from the current frame with integer
/// math only — bit-stable by construction.
final demoComposition = CompositionEntry(
  key: 'demo',
  width: 320,
  height: 240,
  fps: 30,
  frameCount: 48,
  build: () => const DemoComposition(),
);

/// The widget tree behind the `demo` key: `VideoScope` → `SceneScope` →
/// frame-derived background.
class DemoComposition extends StatelessWidget {
  /// Creates the demo composition.
  const DemoComposition({super.key});

  @override
  Widget build(BuildContext context) {
    return const VideoScope(
      fps: 30,
      duration: Time.frames(48),
      child: SceneScope(duration: Time.frames(48), child: _FrameBackground()),
    );
  }
}

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
