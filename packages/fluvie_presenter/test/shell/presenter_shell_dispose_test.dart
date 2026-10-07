import 'dart:async';

import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';
import 'package:fluvie_presenter/src/shell/fullscreen/fullscreen_controller.dart';
import 'package:fluvie_presenter/src/shell/presenter_shell.dart';

/// A fullscreen controller whose platform round-trips park until the test
/// lands them, so a test decides exactly when a transition finishes relative
/// to the shell going away.
final class _ParkedFullscreenController extends FullscreenController {
  final Completer<void> entered = Completer<void>();
  final Completer<bool> reported = Completer<bool>();

  @override
  Future<void> enter() => entered.future;

  @override
  Future<void> exit() async {}

  @override
  Future<bool> get isFullscreen => reported.future;
}

Video _deck() => Video(
  width: 320,
  height: 180,
  scenes: const [
    Scene(
      duration: Time.seconds(1),
      children: [Text('one', style: TextStyle(fontSize: 16))],
    ),
  ],
);

Widget _shell(Video video, FullscreenController fullscreen) {
  final plans = compileSlidePlans(video);
  final container = ProviderContainer(
    overrides: [
      slidePlansProvider.overrideWithValue(plans),
      slideNotesProvider.overrideWithValue(compileNotes(video, plans)),
      fullscreenControllerProvider.overrideWithValue(fullscreen),
    ],
  );
  addTearDown(container.dispose);
  return UncontrolledProviderScope(
    container: container,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 800,
          height: 600,
          child: PresenterShell(video: video, startFullscreen: true),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a shell closed mid-transition never reads a disposed ref', (tester) async {
    final fullscreen = _ParkedFullscreenController();
    await tester.pumpWidget(_shell(_deck(), fullscreen));
    // The post-frame request is parked in the platform's fullscreen call.
    await tester.pump();

    // The presentation closes while that request is still in flight.
    await tester.pumpWidget(const SizedBox.shrink());
    fullscreen.entered.complete();
    await tester.pump();
    fullscreen.reported.complete(true);
    await tester.pump();
  });
}
