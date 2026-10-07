import 'package:slides/loader/fluvie_file_saver_io.dart'
    if (dart.library.js_interop) 'package:slides/loader/fluvie_file_saver_web.dart';

/// Writes a `.fluvie` document to the user's machine, remembering the
/// target so a plain Save needs no dialog after the first one.
abstract interface class FluvieFileSaver {
  /// The saver for the running platform: a system save dialog plus a file
  /// write on desktop; the File System Access API where the browser has it,
  /// a download otherwise, on the web.
  factory FluvieFileSaver.platform() => platformFluvieFileSaver();

  /// The remembered target's file path, or null where paths mean nothing
  /// (the web) or before the first save. The recents list reads it.
  String? get targetPath;

  /// Saves [contents]. [suggestedName] seeds the first dialog; [pickNew]
  /// forces the dialog again (Save as). Returns the saved file's name, or
  /// null when the user cancelled.
  Future<String?> save({
    required String suggestedName,
    required String contents,
    bool pickNew = false,
  });

  /// Saves [contents] to a freshly picked target WITHOUT retargeting: the
  /// remembered target — and the open document's dirty state — keep
  /// pointing at the original. Returns the copy's name, or null when the
  /// user cancelled.
  Future<String?> saveCopy({required String suggestedName, required String contents});

  /// Saves binary [bytes] to a freshly picked target WITHOUT retargeting —
  /// the copy channel for non-document artifacts (the PDF export). The
  /// pick's extension follows [suggestedName]'s. Returns the file's name,
  /// or null when the user cancelled.
  Future<String?> saveCopyBytes({required String suggestedName, required List<int> bytes});

  /// Saves a `.fluvie` bundle's [bytes] (the zip form a deck with session
  /// media takes), with the same target memory as [save]. Returns the saved
  /// file's name, or null when the user cancelled.
  Future<String?> saveBundle({
    required String suggestedName,
    required List<int> bytes,
    bool pickNew = false,
  });
}
