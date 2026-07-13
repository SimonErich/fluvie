// Compiled, tested snippets for the presenter docs. They live here, not
// hand-typed in Markdown, so the documentation never drifts from a real API.
// Each `#docregion` flows into one fence via a `<!-- code-excerpt -->` marker.
import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';
import 'package:obers_ui/obers_ui.dart' show OiThemeData;

/// Five lines, running: hand the presenter a deck.
// #docregion five-lines
void presentIt(Video video) {
  runApp(FluvieSlides(video));
}
// #enddocregion five-lines

/// The whole config surface.
// #docregion config-flags
Widget configured(Video video) => FluvieSlides(
  video,
  showSidebar: true, // the slide list starts open (T toggles it)
  showNotes: true, // the notes panel starts open (N toggles it)
  startFullscreen: true, // request fullscreen once mounted
  theme: PresenterTheme(
    tokens: OiThemeData.dark(), // obers_ui tokens for the chrome
    stageBackground: const Color(0xFF0B2027), // behind the letterboxed slide
  ),
);
// #enddocregion config-flags

/// The speaker window's root, mounted on the speaker route.
// #docregion speaker-root
Widget speakerWindow(Video video) => FluvieSpeaker(video);
// #enddocregion speaker-root

/// Plugging a desktop multi-window opener into the launcher seam.
// #docregion custom-launcher
final class MyDesktopLauncher implements SpeakerWindowLauncher {
  const MyDesktopLauncher();

  @override
  Future<SpeakerLaunchResult> open() async {
    // Create your second window here (desktop_multi_window, a platform
    // channel, whatever your shell uses), then report what happened.
    return const SpeakerLaunchResult.fallback();
  }
}

Widget withDesktopLauncher(Video video) => ProviderScope(
  overrides: [speakerWindowLauncherProvider.overrideWithValue(const MyDesktopLauncher())],
  child: FluvieSlides(video),
);
// #enddocregion custom-launcher

/// Driving navigation yourself: the controller is a public provider.
// #docregion custom-navigation
final class NextButton extends ConsumerWidget {
  const NextButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(presentationControllerProvider.notifier);
    final position = ref.watch(presentationControllerProvider).position;
    return GestureDetector(
      onTap: controller.next,
      child: Text('slide ${position.slide + 1}, step ${position.step}'),
    );
  }
}

// #enddocregion custom-navigation
