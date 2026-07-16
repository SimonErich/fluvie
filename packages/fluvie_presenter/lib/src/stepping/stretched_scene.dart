import 'package:fluvie/fluvie.dart' show Scene, Time;

/// The slide horizon: a scene duration long enough that a held slide never
/// runs out (about nineteen hours at 60 fps). Input paces a presentation,
/// not the authored length.
const int slideHorizonFrames = 1 << 22;

/// The authored [scene], re-bounded for presenting: same content, camera,
/// and defaults, with the duration stretched to [slideHorizonFrames].
///
/// The stretch is what makes holds free — the clock keeps running (so
/// ambient loops never pause) and end-anchored exits sit at the horizon, so
/// they never play; slides leave via the presenter's own transitions
/// instead. Two authored details read differently on a stretched scene, and
/// the docs say so: relative `Time`s resolve against the horizon, and the
/// scene's own enter/exit transitions are handled by the presenter, not the
/// compositor.
Scene stretchSceneForSlide(Scene scene) => Scene(
  duration: const Time.frames(slideHorizonFrames),
  background: scene.background,
  motionDefaults: scene.motionDefaults,
  audio: scene.audio,
  camera: scene.camera,
  children: scene.children,
);
