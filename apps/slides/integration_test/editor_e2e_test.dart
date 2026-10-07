@Tags(['e2e'])
library;

// The slides end-to-end suite: every journey drives the real editor app on the
// Linux desktop embedder, taps real controls, and asserts real outcomes. Every
// early UI seam is faked; the professional journey uses real FFmpeg media
// and disk saves, with only OS file pickers replaced. Run with:
//   flutter test integration_test -d linux
//
// One file on purpose: `flutter test <dir> -d linux` relaunches the desktop app
// per file and only the first launch attaches a debug connection reliably, so
// the whole suite lives here as sibling testWidgets under one launch.
//
// The editor and presenter run live clocks (a text cursor blinks, the presenter
// plays), so the authoring journey steps with pump(), never pumpAndSettle.

import 'dart:convert' show latin1;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show Box, BundleMedia, MediaFileBase, Placed;
import 'package:fluvie_editor/fluvie_editor.dart'
    show
        EditorCanvas,
        EditorDocument,
        EditorDocumentMedia,
        EditorInspector,
        MediaPick,
        ThemePanel,
        VideoTimebase;
import 'package:fluvie_presenter/fluvie_presenter.dart' show FluvieSlides;
import 'package:integration_test/integration_test.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiIconButton, OiIcons, OiThemeData;
import 'package:slides/editor/editor_screen.dart';
import 'package:slides/editor/session_media_store.dart';
import 'package:slides/loader/open_fluvie_file.dart';
import 'package:slides/loader/start_prefs_store.dart';
import 'package:slides/slides_app.dart';

import '../tool/editor_performance.dart' as performance;
import '../tool/editor_performance_metrics.dart';
import '../tool/professional_editor_journey.dart' as professional;
import 'harness.dart';

part 'editor_e2e_authoring.part.dart';
part 'editor_e2e_geometry.part.dart';
part 'editor_e2e_effects.part.dart';
part 'editor_e2e_assets.part.dart';
part 'editor_e2e_theme.part.dart';
part 'editor_e2e_export.part.dart';
part 'editor_frame_metrics_lifecycle.part.dart';

EditorDocument _document(WidgetTester tester) =>
    tester.widget<EditorCanvas>(find.byType(EditorCanvas)).document;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  professional.main();
  performance.main();

  // Reset the app's global media singletons between journeys so no journey
  // inherits another's media scope.
  tearDown(() {
    sessionMediaStore.clear();
    BundleMedia.current = null;
    MediaFileBase.current = null;
  });

  _registerAuthoringJourney();
  _registerGeometryJourney();
  _registerEffectsJourney();
  _registerAssetsJourney();
  _registerThemeJourney();
  _registerExportJourneys();
  _registerMetricsLifecycle();
}
