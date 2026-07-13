/// Present a Fluvie `Video` live: the same scenes and timing engine, played
/// as slides in Flutter and stepped by input like Keynote or reveal.js.
///
/// You write a `Video`, hand it to the presenter, and present it:
///
/// ```dart
/// runApp(FluvieSlides(video));
/// ```
library;

/// The package name, exposed so the wiring smoke test has one honest symbol
/// to assert on before the presenter grows its real surface.
const String fluviePresenterPackageName = 'fluvie_presenter';
