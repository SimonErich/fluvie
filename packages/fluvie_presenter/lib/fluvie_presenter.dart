/// Present a Fluvie `Video` live: the same scenes and timing engine, played
/// as slides in Flutter and stepped by input like Keynote or reveal.js.
///
/// You write a `Video`, hand it to the presenter, and present it:
///
/// ```dart
/// runApp(FluvieSlides(video));
/// ```
library;

export 'src/player/live_scene_player.dart' show LiveScenePlayer;
export 'src/shell/fluvie_slides.dart' show FluvieSlides;
export 'src/stepping/stop.dart' show Stop;
export 'src/stepping/stop_state.dart' show HiddenStop, RevealedStop, StopState;
