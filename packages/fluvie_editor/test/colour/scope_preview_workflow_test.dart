import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:fluvie_editor/src/colour/scope_preview.dart';

void main() {
  testWidgets('scopes read painted frames and follow replaced clocks without stale listeners', (
    tester,
  ) async {
    final scopes = ColourScopesController(interval: const Duration(milliseconds: 1));
    final first = LivePlaybackController(fps: 30);
    final second = LivePlaybackController(fps: 30);
    addTearDown(scopes.dispose);
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    Future<void> mount(LivePlaybackController clock, String digest, Color colour) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: ScopePreview(
                controller: scopes,
                clock: clock,
                digest: digest,
                child: ColoredBox(color: colour),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 2));
      await tester.runAsync(() async {
        for (var i = 0; i < 100 && scopes.data?.red[colour.r == 1 ? 255 : 0] != 256; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      });
    }

    await mount(first, 'first', const Color(0xffff0000));
    expect(scopes.error, isNull);
    expect(scopes.data!.samples, 256);
    expect(scopes.data!.red[255], 256);
    await mount(second, 'second', const Color(0xff000000));
    expect(scopes.data!.red[0], 256);
    final black = scopes.data;
    first.seek(15);
    await tester.pump(const Duration(milliseconds: 2));
    expect(scopes.data, same(black));
    second.seek(7);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    expect(scopes.data!.red[0], 256);
    expect(scopes.error, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    second.seek(8);
    await tester.pump(const Duration(milliseconds: 2));
    expect(tester.takeException(), isNull);
  });
}
