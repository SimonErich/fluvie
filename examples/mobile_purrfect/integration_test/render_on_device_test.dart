@Tags(['render'])
@Timeout(Duration(minutes: 10))
library;

// End-to-end on-device render: launch the app on an Android emulator, enter a
// name, tap Make the card, let the native encoder produce the MP4, then assert
// the file is a real MP4 (ftyp box). Run in CI on an emulator:
//   flutter test integration_test/render_on_device_test.dart -d emulator-5554
//
// Patrol is the documented richer option for native gesture/permission
// automation; this first-party integration_test gives a dependency-free e2e.

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_purrfect/app.dart';
import 'package:mobile_purrfect/compose/compose_state.dart';
import 'package:mobile_purrfect/compose/compose_view_model.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders a birthday card to a valid MP4 on the device', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MobilePurrfectApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('cat-name')), 'Mittens');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('render-button')));
    await tester.pump();

    // Wait for the native render to finish, letting real async run.
    final deadline = DateTime.now().add(const Duration(minutes: 8));
    await tester.runAsync(() async {
      while (container.read(composeViewModelProvider).isRendering &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    });
    await tester.pumpAndSettle();

    final state = container.read(composeViewModelProvider);
    expect(
      state.status,
      ComposeStatus.done,
      reason: state.error ?? 'render did not finish',
    );

    final file = File(state.outputPath!);
    expect(file.existsSync(), isTrue);
    final bytes = file.readAsBytesSync();
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.sublist(4, 8)), 'ftyp');
  });
}
