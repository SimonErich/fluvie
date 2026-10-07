import 'dart:async' show unawaited;
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart' show MediaFileBase, Video;
import 'package:fluvie_editor/fluvie_editor.dart' show EditorDocument, documentBundleValues;
import 'package:fluvie_presenter/fluvie_presenter.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:slides/deck/deck_registry.dart';
import 'package:slides/editor/demo_spec.dart';
import 'package:slides/editor/editor_screen.dart';
import 'package:slides/editor/session_media_store.dart';
import 'package:slides/loader/autosave_record.dart';
import 'package:slides/loader/autosave_store.dart';
import 'package:slides/loader/fluvie_file_saver.dart';
import 'package:slides/loader/open_fluvie_file.dart';
import 'package:slides/loader/open_fluvie_path.dart';
import 'package:slides/loader/recent_deck.dart';
import 'package:slides/loader/recent_decks_store.dart';
import 'package:slides/loader/start_prefs_store.dart';
import 'package:slides/routing/session_media_urls.dart';
import 'package:slides/routing/speaker_deck_payload.dart';
import 'package:slides/routing/speaker_route.dart';
import 'package:slides/start/start_screen.dart';

part 'slides_app_open.dart';
part 'slides_app_prefs.dart';
part 'slides_app_recents.dart';
part 'slides_app_recovery.dart';
part 'slides_app_state.dart';

/// The Fluvie slides shell: pick a bundled tutorial deck, a recent deck, or
/// a local `.fluvie` file, then present or edit it.
///
/// All presentation logic lives in `package:fluvie_presenter`; this app only
/// decides what to present (and, on the web, hands the choice to the
/// speaker popup through local storage).
final class SlidesApp extends StatefulWidget {
  /// Creates the shell.
  const SlidesApp({
    this.openFile = openFluvieFile,
    this.openPath = openFluvieFileAtPath,
    this.saver,
    this.recents,
    this.startPrefs,
    this.autosave,
    this.sessionMedia,
    this.storeSpeaker,
    this.layoutSettings = const OiLocalStorageDriver(prefix: 'fluvie.slides'),
    super.key,
  });

  /// How the file actions obtain a deck; tests inject a fake picker.
  final Future<LoadedDeck?> Function() openFile;

  /// How a recent entry reopens by path; tests inject a fake reader.
  final Future<LoadedDeck> Function(String path) openPath;

  /// How the editor saves; null takes the platform saver, tests inject one.
  final FluvieFileSaver? saver;

  /// Where the recents list lives; null takes the platform store.
  final RecentDecksStore? recents;

  /// Where the editor shell persists its panel layout.
  ///
  /// Defaults to the platform store (shared preferences off the web, local
  /// storage on it) so a reopened editor looks the way it was left; a test
  /// passes an in-memory driver, or null to lay out without remembering.
  final OiSettingsDriver? layoutSettings;

  /// Where the start screen's remembered preferences live (the first-run
  /// tips dismissal); null takes the platform store.
  final StartPrefsStore? startPrefs;

  /// Where crash-recovery autosaves live; null takes the platform store.
  final AutosaveStore? autosave;

  /// The session media store recoveries adopt into and speaker payloads
  /// read from; null takes the app session.
  final SessionMediaStore? sessionMedia;

  /// How presenting records the deck for the speaker popup; null takes the
  /// platform handoff (localStorage on the web, a no-op on desktop).
  final void Function({required String kind, required String payload})? storeSpeaker;

  @override
  State<SlidesApp> createState() => _SlidesAppState();
}
