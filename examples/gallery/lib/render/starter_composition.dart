import 'package:fluvie_example/render/composition_entry.dart';
import 'package:fluvie_example/starter/starter_video.dart';

/// The `starter` composition: the same `Video` that `fluvie init` scaffolds,
/// registered so the harness can render it and the getting-started docs can show
/// a real, rendered clip.
const CompositionEntry starterComposition = CompositionEntry(
  key: 'starter',
  video: starterVideo,
);
