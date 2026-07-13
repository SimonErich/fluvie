import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:fluvie/fluvie.dart' show Video, VideoSpec, buildVideo;

/// The outcome of opening a `.fluvie` file: a deck, a friendly error, or
/// nothing (the user cancelled the picker).
final class LoadedDeck {
  /// A deck loaded from [name].
  const LoadedDeck.video(this.name, Video this.video, String this.rawJson) : error = null;

  /// A file that did not parse; [error] says why.
  const LoadedDeck.failed(this.name, String this.error) : video = null, rawJson = null;

  /// The picked file's name.
  final String name;

  /// The loaded deck, or `null` on failure.
  final Video? video;

  /// The original JSON text, kept so the speaker window can load the same
  /// deck from the handoff store.
  final String? rawJson;

  /// What went wrong, or `null` on success.
  final String? error;
}

/// Parses `.fluvie` JSON [text] into a deck — the pure half of the loader,
/// shared by the file picker and the speaker-window handoff.
LoadedDeck parseFluvieJson(String name, String text) {
  try {
    final json = jsonDecode(text);
    if (json is! Map<String, Object?>) {
      return LoadedDeck.failed(name, 'A .fluvie file holds one JSON object.');
    }
    return LoadedDeck.video(name, buildVideo(VideoSpec.fromJson(json)), text);
  } on FormatException catch (error) {
    return LoadedDeck.failed(name, 'This is not valid JSON: ${error.message}');
  } on Object catch (error) {
    return LoadedDeck.failed(name, 'The spec did not resolve: $error');
  }
}

/// Opens the system picker for a `.fluvie` (or `.json`) file and parses it.
/// Returns `null` when the user cancels.
Future<LoadedDeck?> openFluvieFile() async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['fluvie', 'json'],
    withData: true,
  );
  final file = result?.files.firstOrNull;
  final bytes = file?.bytes;
  if (file == null || bytes == null) return null;
  return parseFluvieJson(file.name, utf8.decode(bytes));
}
