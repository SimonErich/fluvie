import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:slides/loader/fluvie_file_saver.dart';

// coverage:ignore-start the real save dialog needs a live platform channel

/// The desktop saver: a system dialog on the first save and on Save as,
/// silent rewrites of the remembered path afterwards.
FluvieFileSaver platformFluvieFileSaver() => _DesktopFluvieFileSaver();

final class _DesktopFluvieFileSaver implements FluvieFileSaver {
  String? _path;

  @override
  String? get targetPath => _path;

  @override
  Future<String?> save({
    required String suggestedName,
    required String contents,
    bool pickNew = false,
  }) async {
    var path = _path;
    if (pickNew || path == null) {
      path = await _pick(suggestedName);
      if (path == null) return null;
      _path = path;
    }
    await File(path).writeAsString(contents);
    return path.split(Platform.pathSeparator).last;
  }

  @override
  Future<String?> saveCopy({required String suggestedName, required String contents}) async {
    // Always a fresh dialog, and the remembered target stays put.
    final path = await _pick(suggestedName);
    if (path == null) return null;
    await File(path).writeAsString(contents);
    return path.split(Platform.pathSeparator).last;
  }

  @override
  Future<String?> saveCopyBytes({
    required String suggestedName,
    required List<int> bytes,
  }) async {
    // A fresh dialog every time, and the remembered target stays put.
    final extension = suggestedName.contains('.') ? suggestedName.split('.').last : 'bin';
    final path = await FilePicker.saveFile(
      dialogTitle: 'Save .$extension',
      fileName: suggestedName,
      type: FileType.custom,
      allowedExtensions: [extension],
    );
    if (path == null) return null;
    await File(path).writeAsBytes(bytes);
    return path.split(Platform.pathSeparator).last;
  }

  @override
  Future<String?> saveBundle({
    required String suggestedName,
    required List<int> bytes,
    bool pickNew = false,
  }) async {
    var path = _path;
    if (pickNew || path == null) {
      path = await _pick(suggestedName);
      if (path == null) return null;
      _path = path;
    }
    await File(path).writeAsBytes(bytes);
    return path.split(Platform.pathSeparator).last;
  }

  Future<String?> _pick(String suggestedName) => FilePicker.saveFile(
    dialogTitle: 'Save .fluvie',
    fileName: suggestedName,
    type: FileType.custom,
    allowedExtensions: const ['fluvie', 'json'],
  );
}

// coverage:ignore-end
