# Custom navigation

The keyboard map covers presenting. When you are building something around
the presenter (a kiosk, a lecture tool, a hardware button on a stand), drive
it yourself: the deck's position is ordinary Riverpod state.

<!-- code-excerpt "../../apps/slides/lib/snippets/presenter_snippets.dart (custom-navigation)" -->
```dart
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
```

`presentationControllerProvider` holds a `PresentationState`: the
`(slide, step)` position plus how it was reached (`forward` plays entrances,
`instant` lands on held states). The notifier is the whole verb set:
`next()`, `back()`, `jumpToSlide(index)`, `jumpToStep(slide, step)`, and the
derived `nextPosition`, `canGoNext`, `canGoBack`, `totalSlides`. Jumps clamp
to the deck, and every rule from the keyboard applies: forward animates,
everything else is instant.

Mount your chrome inside the presenter's scope (anywhere under
`FluvieSlides`) and read the provider; the shell already keeps its own HUD,
sidebar, and speaker window on the same state, so yours cannot drift.

The same seam powers the desktop speaker window:

<!-- code-excerpt "../../apps/slides/lib/snippets/presenter_snippets.dart (custom-launcher)" -->
```dart
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
```

Whatever your launcher opens, mount `FluvieSpeaker` with the same deck in
the new window and the sync channel does the rest.

## Where to next

- [How stepping works](how-stepping-works.md): what forward and instant
  mean underneath.
- [The speaker window](../guides/the-speaker-window.md): the built-in second
  screen.
