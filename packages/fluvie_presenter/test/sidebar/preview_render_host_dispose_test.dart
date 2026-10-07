import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';

Video _deck() => Video(
  width: 320,
  height: 180,
  scenes: [
    for (var s = 0; s < 2; s++)
      Scene(
        duration: const Time.seconds(1),
        background: Background.color(const Color(0xFF223344)),
        children: [Text('slide $s', style: const TextStyle(fontSize: 16))],
      ),
  ],
);

Widget _mounted(GlobalKey<PreviewRenderHostState> key, Video video) => Directionality(
  textDirection: TextDirection.ltr,
  child: Stack(
    children: [
      Positioned(
        top: 0,
        left: 0,
        child: PreviewRenderHost(key: key, video: video, plans: compileSlidePlans(video)),
      ),
    ],
  ),
);

/// The render's outcome: the image when it landed, the error when it did not.
Future<Object?> _outcome(Future<Object?> render) =>
    render.then<Object?>((value) => value, onError: (Object error) => error);

/// Drives the frames the host waits for, then reads the render's outcome
/// through a real async window (the engine read-back needs one) with a
/// timeout, so a render that never settles fails the test instead of hanging.
Future<Object?> _settle(WidgetTester tester, Future<Object?> outcome) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
  return tester.runAsync<Object?>(
    () => outcome.timeout(const Duration(seconds: 5), onTimeout: () => 'never settled'),
  );
}

void main() {
  testWidgets('a render that outlives its host fails with a clear error', (tester) async {
    final hostKey = GlobalKey<PreviewRenderHostState>();
    final video = _deck();
    await tester.pumpWidget(_mounted(hostKey, video));

    final pending = _outcome(hostKey.currentState!.render(0));
    // One frame in: the composition is mounted, the capture is still ahead.
    await tester.pump();
    // The presentation closes while that render is parked.
    await tester.pumpWidget(const SizedBox.shrink());

    expect(
      await _settle(tester, pending),
      isA<StateError>(),
      reason: 'a torn-down host must fail the render, not unwrap a null boundary',
    );
  });

  testWidgets('a render queued behind a torn-down host never starts', (tester) async {
    final hostKey = GlobalKey<PreviewRenderHostState>();
    final video = _deck();
    await tester.pumpWidget(_mounted(hostKey, video));

    final first = _outcome(hostKey.currentState!.render(0));
    final second = _outcome(hostKey.currentState!.render(1));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());

    expect(await _settle(tester, first), isA<StateError>());
    expect(
      await _settle(tester, second),
      isA<StateError>(),
      reason: 'the queued render must fail, not setState on a defunct host',
    );
  });

  testWidgets('a render requested after the host is gone fails fast', (tester) async {
    final hostKey = GlobalKey<PreviewRenderHostState>();
    final video = _deck();
    await tester.pumpWidget(_mounted(hostKey, video));
    final host = hostKey.currentState!;
    await tester.pumpWidget(const SizedBox.shrink());

    expect(await _settle(tester, _outcome(host.render(0))), isA<StateError>());
  });
}
