/// Present a Fluvie `Video` live: the same scenes and timing engine, played
/// as slides in Flutter and stepped by input like Keynote or reveal.js.
///
/// You write a `Video`, hand it to the presenter, and present it:
///
/// ```dart
/// runApp(FluvieSlides(video));
/// ```
library;

export 'src/controller/navigation_kind.dart' show NavigationKind;
export 'src/controller/presentation_controller.dart'
    show PresentationController, presentationControllerProvider, slidePlansProvider;
export 'src/controller/presentation_position.dart' show PresentationPosition;
export 'src/controller/presentation_state.dart' show PresentationState;
export 'src/player/live_scene_player.dart' show LiveScenePlayer;
export 'src/shell/fluvie_slides.dart' show FluvieSlides;
export 'src/stepping/slide_plan.dart' show SlidePlan, SlideStep;
export 'src/stepping/step_compile_error.dart' show StepCompileError;
export 'src/stepping/step_compiler.dart' show compileSlidePlans;
export 'src/stepping/stop.dart' show Stop;
export 'src/stepping/stop_state.dart' show HiddenStop, RevealedStop, StopState;
