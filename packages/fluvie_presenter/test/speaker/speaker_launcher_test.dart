import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';
import 'package:fluvie_presenter/src/shell/presenter_shell.dart';
import 'package:fluvie_presenter/src/shell/ui_state.dart';

final class _OpeningLauncher implements SpeakerWindowLauncher {
  int opens = 0;

  @override
  Future<SpeakerLaunchResult> open() async {
    opens++;
    return const SpeakerLaunchResult.opened();
  }
}

final class _BlockedLauncher implements SpeakerWindowLauncher {
  @override
  Future<SpeakerLaunchResult> open() async =>
      const SpeakerLaunchResult.fallback(url: 'https://slides.example/#/speaker');
}

Video _deck() => Video(
  width: 320,
  height: 180,
  scenes: const [
    Scene(
      duration: Time.seconds(2),
      children: [SpeakerNotes(text: 'the notes')],
    ),
  ],
);

(ProviderContainer, Widget) _present(Video video, SpeakerWindowLauncher launcher) {
  final plans = compileSlidePlans(video);
  final container = ProviderContainer(
    overrides: [
      slidePlansProvider.overrideWithValue(plans),
      slideNotesProvider.overrideWithValue(compileNotes(video, plans)),
      speakerWindowLauncherProvider.overrideWithValue(launcher),
    ],
  );
  addTearDown(container.dispose);
  final widget = UncontrolledProviderScope(
    container: container,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: PresenterShell(video: video),
    ),
  );
  return (container, widget);
}

void main() {
  group('on desktop', () {
    // The widget-test binding defaults to Android; these are desktop paths.
    final onLinux = TargetPlatformVariant.only(TargetPlatform.linux);

    testWidgets('S opens the speaker window when the platform can', variant: onLinux, (
      tester,
    ) async {
      final launcher = _OpeningLauncher();
      final (_, widget) = _present(_deck(), launcher);
      await tester.pumpWidget(widget);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.pump();
      expect(launcher.opens, 1);
      expect(find.textContaining('second window'), findsNothing);
    });

    testWidgets(
      'a blocked window becomes the open-this-URL instruction; Esc clears it',
      variant: onLinux,
      (tester) async {
        final (_, widget) = _present(_deck(), _BlockedLauncher());
        await tester.pumpWidget(widget);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
        await tester.pump();
        await tester.pump();
        expect(
          find.text('Open this link in a second window: https://slides.example/#/speaker'),
          findsOneWidget,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        expect(find.textContaining('second window'), findsNothing);
      },
    );
  });

  testWidgets(
    'on mobile S surfaces the in-app notes panel instead',
    variant: TargetPlatformVariant.only(TargetPlatform.android),
    (tester) async {
      final launcher = _OpeningLauncher();
      final (container, widget) = _present(_deck(), launcher);
      await tester.pumpWidget(widget);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.pump();
      expect(launcher.opens, 0);
      expect(container.read(notesVisibleProvider), isTrue);
      expect(find.text('the notes'), findsOneWidget);
    },
  );
}
