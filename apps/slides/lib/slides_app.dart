import 'package:flutter/widgets.dart';

/// The Fluvie slides shell.
///
/// A thin host for `FluvieSlides`: it loads a presentation (a bundled
/// example, or on the web a local `.fluvie` file) and presents it. All the
/// presentation logic lives in `package:fluvie_presenter`; this app only
/// picks what to present.
final class SlidesApp extends StatelessWidget {
  /// Creates the shell.
  const SlidesApp({super.key});

  @override
  Widget build(BuildContext context) => const Directionality(
    textDirection: TextDirection.ltr,
    child: ColoredBox(
      color: Color(0xFF101014),
      child: Center(
        child: Text(
          'fluvie slides',
          style: TextStyle(color: Color(0xFFF2F2F7), fontSize: 24),
        ),
      ),
    ),
  );
}
