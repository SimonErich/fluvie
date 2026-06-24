@Tags(['render'])
@Timeout(Duration(minutes: 12))
library;

// End-to-end: launch the desktop app, tap Render (the save dialog is faked to a
// temp path), let the real CLI render the promo, then assert and ffprobe the
// file. Runs on Linux under xvfb in CI:
//   xvfb-run -a flutter test integration_test/render_flow_test.dart -d linux

import 'dart:io';

import 'package:desktop_studio/app.dart';
import 'package:desktop_studio/render/save_dialog_service.dart';
import 'package:desktop_studio/studio/studio_state.dart';
import 'package:desktop_studio/studio/studio_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

class _FixedSave implements SaveDialogService {
  _FixedSave(this.path);

  final String path;

  @override
  Future<String?> chooseSavePath(String suggestedName) async => path;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders the selected template to a real MP4 through the UI', (
    tester,
  ) async {
    final outDir = Directory('${Directory.systemTemp.path}/desktop_studio_e2e')
      ..createSync(recursive: true);
    final out = '${outDir.path}/promo.mp4';
    final file = File(out);
    if (file.existsSync()) file.deleteSync();

    final container = ProviderContainer(
      overrides: [saveDialogServiceProvider.overrideWithValue(_FixedSave(out))],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const DesktopStudioApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Draft keeps the render brief, then start it.
    container.read(studioViewModelProvider.notifier).toggleDraft();
    await tester.tap(find.byKey(const ValueKey('render-button')));
    await tester.pump();

    // Wait for the real CLI subprocess to finish, pumping the UI meanwhile.
    final deadline = DateTime.now().add(const Duration(minutes: 10));
    await tester.runAsync(() async {
      while (container.read(studioViewModelProvider).isRendering &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    });
    await tester.pumpAndSettle();

    final state = container.read(studioViewModelProvider);
    expect(
      state.status,
      StudioStatus.done,
      reason: state.error ?? 'render did not finish',
    );
    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), greaterThan(0));

    final probe = await Process.run('ffprobe', [
      '-v',
      'error',
      '-select_streams',
      'v:0',
      '-show_entries',
      'stream=codec_name',
      '-of',
      'default=noprint_wrappers=1:nokey=1',
      out,
    ]);
    expect((probe.stdout as String).trim(), 'h264');
  });
}
