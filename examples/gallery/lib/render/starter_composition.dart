import 'package:flutter/widgets.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie_example/render/composition_entry.dart';
import 'package:fluvie_example/starter/starter_video.dart';

/// The `starter` composition: the same `Video` that `fluvie init` scaffolds,
/// registered so the harness can render it and the getting-started docs can show
/// a real, rendered clip. The probe `Video` is built once for the geometry and
/// the media collect pass; every render builds a fresh tree via [starterVideo].
final CompositionEntry starterComposition = _entryForStarter();

CompositionEntry _entryForStarter() {
  final probe = starterVideo();
  return CompositionEntry(
    key: 'starter',
    width: probe.width,
    height: probe.height,
    fps: probe.fps,
    frameCount: probe.totalFrames,
    mediaSources: collectMediaSources(probe.scenes),
    build: () => Directionality(textDirection: TextDirection.ltr, child: starterVideo()),
  );
}
