import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:integration_test/integration_test.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:slides/editor/deck_render_service_io.dart';
import 'package:slides/editor/editor_screen.dart';
import 'package:slides/editor/file_media_importer.dart';
import 'package:slides/loader/fluvie_file_saver.dart';

import '../integration_test/harness.dart';

part 'professional_editor_fixtures.part.dart';
part 'professional_editor_authoring.part.dart';
part 'professional_editor_oracle.part.dart';

EditorCanvas _canvas(WidgetTester tester) =>
    tester.widget<EditorCanvas>(find.byType(EditorCanvas).first);
VideoModePanel _timeline(WidgetTester tester) =>
    tester.widget<VideoModePanel>(find.byType(VideoModePanel));

Future<void> _until(WidgetTester tester, bool Function() done, {int seconds = 90}) async {
  final deadline = DateTime.now().add(Duration(seconds: seconds));
  while (!done() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
  }
  expect(done(), isTrue, reason: 'The editor operation did not finish within $seconds seconds');
  await tester.pump();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real media survives the complete project and batch delivery journey', (
    tester,
  ) async {
    useDesktopSurface(tester);
    final directory = Directory(
      Platform.environment['FLUVIE_ACCEPTANCE_DIR'] ??
          '${Directory.systemTemp.path}/fluvie_editor_acceptance',
    );
    final picks = await _createJourneyFixtures(tester, directory);
    final authored = await _authorJourney(tester, directory, picks);
    await _deliverJourney(tester, directory, authored);
    await _verifyJourney(tester, directory, authored);
  }, timeout: const Timeout(Duration(minutes: 8)));
}
