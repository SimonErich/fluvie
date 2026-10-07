import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'layout': 'canvas',
      'background': {'kind': 'color', 'color': '#223344'},
      'children': [
        {
          'id': 'el-box',
          'type': 'Box',
          'color': '#6C5CE7',
          'transform': {'x': 0.5, 'y': 0.5, 'w': 0.4, 'h': 0.4},
        },
      ],
    },
    {'duration': '30f', 'children': <Object?>[]},
  ],
};

Widget _mounted(GlobalKey<DocumentPreviewHostState> key) => Directionality(
  textDirection: TextDirection.ltr,
  child: Stack(
    children: [
      Positioned(
        top: 0,
        left: 0,
        child: DocumentPreviewHost(key: key, document: EditorDocument.fromJson(_deck())),
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
    final hostKey = GlobalKey<DocumentPreviewHostState>();
    await tester.pumpWidget(_mounted(hostKey));

    final pending = _outcome(hostKey.currentState!.render(0));
    // One frame in: the composition is mounted, the capture is still ahead.
    await tester.pump();
    // The deck closes while that render is parked.
    await tester.pumpWidget(const SizedBox.shrink());

    expect(
      await _settle(tester, pending),
      isA<StateError>(),
      reason: 'a torn-down host must fail the render, not unwrap a null boundary',
    );
  });

  testWidgets('a render queued behind a torn-down host never starts', (tester) async {
    final hostKey = GlobalKey<DocumentPreviewHostState>();
    await tester.pumpWidget(_mounted(hostKey));

    // The editor runs the preview service two renders at a time, so a
    // second render is always parked behind the first.
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
    final hostKey = GlobalKey<DocumentPreviewHostState>();
    await tester.pumpWidget(_mounted(hostKey));
    final host = hostKey.currentState!;
    await tester.pumpWidget(const SizedBox.shrink());

    expect(await _settle(tester, _outcome(host.render(0))), isA<StateError>());
  });
}
