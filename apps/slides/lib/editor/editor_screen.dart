// printVideoSpecJson is @experimental in fluvie_cli; the Dart export depends
// on it deliberately (the one supported spec-to-Dart printer).
// ignore_for_file: experimental_member_use
import 'dart:async' show unawaited;
import 'dart:convert' show JsonEncoder, jsonEncode, utf8;
import 'dart:typed_data' show Uint8List;
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie/fluvie.dart'
    show FrameSpan, MediaFileBase, Video, VideoSpec, introspectTimeline;
import 'package:fluvie/rendering.dart' show WaveformEnvelope, WebClipDecoder;
import 'package:fluvie_cli/codegen.dart' show printVideoSpecJson;
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart' show FluvieSlides, SlidePreviewService;
import 'package:fluvie_web_encoder/fluvie_web_encoder.dart' show createWebClipDecoder;
import 'package:obers_ui/obers_ui.dart';
import 'package:slides/editor/audio_preview_controller.dart';
import 'package:slides/editor/audio_preview_platform.dart' show AudioPreviewPlatform;
import 'package:slides/editor/autosave_controller.dart';
import 'package:slides/editor/deck_render_service.dart';
import 'package:slides/editor/editor_top_bar.dart';
import 'package:slides/editor/editor_view_settings.dart';
import 'package:slides/editor/export_progress_dialog.dart';
import 'package:slides/editor/export_video_dialog.dart';
import 'package:slides/editor/file_media_importer.dart';
import 'package:slides/editor/session_media_store.dart';
import 'package:slides/editor/slide_image_exporter.dart';
import 'package:slides/editor/slide_pdf.dart';
import 'package:slides/editor/timeline_filmstrips.dart';
import 'package:slides/loader/autosave_record.dart';
import 'package:slides/loader/autosave_store.dart';
import 'package:slides/loader/fluvie_bundle.dart';
import 'package:slides/loader/fluvie_file_saver.dart';
import 'package:slides/loader/relative_media_paths.dart';
import 'package:slides/routing/session_media_urls.dart';
import 'package:slides/routing/speaker_deck_payload.dart';
import 'package:slides/routing/speaker_route.dart';
import 'package:slides/templates/deck_templates.dart';

part 'editor_screen_export.dart';
part 'editor_screen_files.dart';
part 'editor_screen_media.dart';
part 'editor_screen_media_save.dart';
part 'editor_screen_panels.dart';
part 'editor_screen_stage.dart';
part 'editor_screen_delivery.dart';
part 'editor_screen_source.dart';
part 'editor_screen_state.dart';
part 'editor_screen_session_sync.dart';
part 'editor_screen_preferences.dart';
part 'editor_screen_transport.dart';
part 'editor_screen_video.dart';
part 'editor_screen_video_stage.dart';
part 'editor_screen_workspaces.dart';
part 'editor_screen_preview_status.dart';

/// Edit mode's host: the interactive canvas over one slide of the document,
/// undo and redo, save with a dirty guard, Present, a slide stepper, and
/// the way back.
final class EditorScreen extends StatefulWidget {
  /// Opens [document] for editing at slide zero.
  const EditorScreen({
    required this.document,
    required this.title,
    required this.onClose,
    this.saver,
    this.importer,
    this.render,
    this.images,
    this.autosave,
    this.autosaveKey,
    this.savedDigest,
    this.sessionMedia,
    this.speakerMediaUrl,
    this.storeSpeaker,
    this.onDeckSaved,
    this.onDeckRenamed,
    this.layoutSettings,
    this.audioPreviewPlatform,
    super.key,
  });

  /// Optional platform output seam for hosted/test sessions. The editor owns
  /// its lifetime; production uses native ffplay or browser Web Audio.
  final AudioPreviewPlatform? audioPreviewPlatform;

  /// The deck as it was opened.
  final EditorDocument document;

  /// What the top bar calls the deck, until Save as renames it.
  final String title;

  /// Back to the picker (guarded while changes are unsaved).
  final VoidCallback onClose;

  /// Where the shell persists its panel layout, or null to lay out without
  /// remembering.
  ///
  /// Injected rather than constructed here so a test drives an in-memory
  /// driver and never touches real storage; the app passes the platform one.
  final OiSettingsDriver? layoutSettings;

  /// How saving writes the file; null takes the platform saver.
  final FluvieFileSaver? saver;

  /// How the media tool picks a file; null takes the platform picker.
  final MediaImporter? importer;

  /// How Export video renders the deck; null takes the platform service
  /// (the real pipeline on desktop, unavailable on the web).
  final DeckRenderService? render;

  /// How Export slide images saves its PNGs; null takes the platform
  /// exporter (a folder pick on desktop, downloads on the web).
  final SlideImageExporter? images;

  /// Where crash-recovery autosaves live; null takes the platform store.
  final AutosaveStore? autosave;

  /// The deck's autosave identity on open (the file path when it has one,
  /// the deck name otherwise); null falls back to [title]. A completed
  /// save retargets it to the saved path.
  final String? autosaveKey;

  /// The digest of the document as last saved to disk; null means
  /// [document] IS the saved state. A recovery open passes the file's
  /// digest here so the recovered document starts out unsaved.
  final String? savedDigest;

  /// The session media the deck's `bundle` sources resolve through (web
  /// imports and opened bundles); null takes the app session. A bundle save
  /// reads its bytes back.
  final SessionMediaStore? sessionMedia;

  /// How Present mints a popup-readable URL for one session media entry;
  /// null takes the platform minter (object URLs on the web, nothing on
  /// desktop, where no popup exists).
  final String? Function(String value, Uint8List bytes)? speakerMediaUrl;

  /// How Present records the deck for the speaker popup; null takes the
  /// platform handoff (localStorage on the web, a no-op on desktop).
  final void Function({required String kind, required String payload})? storeSpeaker;

  /// Hears about a completed save (the saved name and the saver's target
  /// path where one exists) — how the host keeps its recents list.
  final void Function(String name, String? path)? onDeckSaved;

  /// Hears about an inline deck rename (the new name and the current
  /// target path).
  final void Function(String name, String? path)? onDeckRenamed;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

/// Which left panel is open.
enum _LeftTab { slides, layers, theme, titles }

typedef _QueuedVideo = ({VideoSpec spec, ExportOptions options, String name});
