import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:fluvie/fluvie.dart' show MediaFileBase, Video, VideoSpec, buildVideo;
import 'package:slides/editor/session_media_store.dart';
import 'package:slides/loader/fluvie_bundle.dart';
import 'package:slides/loader/relative_media_paths.dart';

/// The outcome of opening a `.fluvie` file: a deck, a friendly error, or
/// nothing (the user cancelled the picker).
final class LoadedDeck {
  /// A deck loaded from [name].
  const LoadedDeck.video(this.name, Video this.video, String this.rawJson, {this.path})
    : error = null;

  /// A file that did not parse; [error] says why.
  const LoadedDeck.failed(this.name, String this.error, {this.path}) : video = null, rawJson = null;

  /// The picked file's name.
  final String name;

  /// Where the file lives, when the platform knows (desktop picks and
  /// by-path reopens); null on the web and for drops.
  final String? path;

  /// The loaded deck, or `null` on failure.
  final Video? video;

  /// The original JSON text, kept so the speaker window can load the same
  /// deck from the handoff store.
  final String? rawJson;

  /// What went wrong, or `null` on success.
  final String? error;
}

/// Decodes `.fluvie` [text] into its JSON object (the editor's entry).
/// Throws a [FormatException] when it is not a JSON object.
Map<String, Object?> parseRawJson(String text) {
  final json = jsonDecode(text);
  if (json is! Map<String, Object?>) {
    throw const FormatException('A .fluvie file holds one JSON object.');
  }
  return json;
}

/// Parses `.fluvie` JSON [text] into a deck — the pure half of the loader,
/// shared by the file picker, by-path reopens, and the speaker-window
/// handoff. A non-null [path] rides along for the recents list.
LoadedDeck parseFluvieJson(String name, String text, {String? path}) {
  try {
    final json = jsonDecode(text);
    if (json is! Map<String, Object?>) {
      return LoadedDeck.failed(name, 'A .fluvie file holds one JSON object.', path: path);
    }
    return LoadedDeck.video(name, buildVideo(VideoSpec.fromJson(json)), text, path: path);
  } on FormatException catch (error) {
    return LoadedDeck.failed(name, 'This is not valid JSON: ${error.message}', path: path);
  } on Object catch (error) {
    return LoadedDeck.failed(name, 'The spec did not resolve: $error', path: path);
  }
}

/// Parses `.fluvie` [bytes] by sniffing their form: the zip magic (`PK`)
/// means a bundle — its media is adopted into [session] (the app session by
/// default) and the published `BundleMedia` scope resolves the deck's
/// `bundle` sources — anything else parses as plain JSON. Either way the
/// previous session's media retires first: one open document, one session.
/// A known [path] also publishes the document's folder as the
/// [MediaFileBase], so relative `file` media values resolve against it; a
/// pathless open (the web, drops) clears the scope.
Future<LoadedDeck> parseFluvieBytes(
  String name,
  List<int> bytes, {
  String? path,
  SessionMediaStore? session,
}) async {
  MediaFileBase.current = path == null ? null : directoryOfPath(path);
  final media = (session ?? sessionMediaStore)..clear();
  if (!isZipBytes(bytes)) return parseFluvieJson(name, utf8.decode(bytes), path: path);
  try {
    final bundle = readFluvieBundle(bytes);
    await media.adopt(bundle.media);
    return parseFluvieJson(name, bundle.deckJson, path: path);
  } on FluvieBundleException catch (error) {
    return LoadedDeck.failed(name, 'This bundle could not be opened: ${error.message}', path: path);
  } on SessionMediaBudgetError catch (error) {
    return LoadedDeck.failed(name, 'This bundle could not be opened: $error', path: path);
  }
}

/// Parses a file dropped onto the app. The drop payload's bytes are loosely
/// typed upstream, so anything that is not a byte list (or is empty) becomes
/// a friendly error instead of a crash.
Future<LoadedDeck> parseDroppedFluvie(String name, Object? bytes) async {
  if (bytes is! List<int> || bytes.isEmpty) {
    return LoadedDeck.failed(name, 'The dropped file arrived without content.');
  }
  return parseFluvieBytes(name, bytes);
}

/// Opens the system picker for a `.fluvie` (or `.json`) file and parses it.
/// Returns `null` when the user cancels.
// coverage:ignore-start the real picker needs a live platform channel
Future<LoadedDeck?> openFluvieFile() async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['fluvie', 'json'],
    withData: true,
  );
  final file = result?.files.firstOrNull;
  final bytes = file?.bytes;
  if (file == null || bytes == null) return null;
  // PlatformFile.path is unavailable on the web; kIsWeb guards the read.
  return parseFluvieBytes(file.name, bytes, path: kIsWeb ? null : file.path);
}

// coverage:ignore-end
