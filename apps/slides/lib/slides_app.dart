import 'package:flutter/widgets.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';
import 'package:slides/demo/hello_presentation.dart';

/// The Fluvie slides shell.
///
/// A thin host for [FluvieSlides]: it decides what to present (a bundled
/// example, or on the web a local `.fluvie` file) and hands the `Video` to
/// the presenter. All presentation logic lives in `package:fluvie_presenter`.
final class SlidesApp extends StatelessWidget {
  /// Creates the shell.
  const SlidesApp({super.key});

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: FluvieSlides(helloPresentation()),
  );
}
